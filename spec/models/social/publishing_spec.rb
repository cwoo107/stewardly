require "rails_helper"

RSpec.describe Social::Publishing do
  let(:facebook) { create(:social_account) }
  let(:instagram) { create(:social_account, :instagram) }
  let(:provider) { instance_double(Social::Providers::Meta) }

  before { allow_any_instance_of(SocialAccount).to receive(:provider).and_return(provider) }

  def scheduled_post(accounts, photos: 0)
    post = create(:social_post, accounts:)
    photos.times { |i| post.media.attach(io: file_fixture("landscape.png").open, filename: "p#{i}.png", content_type: "image/png") }
    post.update!(status: "scheduled", scheduled_at: 1.minute.ago)
    post.targets.update_all(status: "pending", next_attempt_at: 1.minute.ago)
    post.reload
  end

  it "publishes each target once, records the link, and a rerun does nothing" do
    post = scheduled_post([ facebook ])
    allow(provider).to receive(:publish).and_return(Social::Provider::PublishResult.new("123_456", "https://facebook.com/123_456"))
    target = post.targets.first
    described_class.new(target).publish!
    described_class.new(target.reload).publish!
    expect(provider).to have_received(:publish).once
    expect(target).to have_attributes(status: "published", external_post_id: "123_456", permalink: "https://facebook.com/123_456")
    expect(post.reload).to be_published
  end

  it "retries transient errors with backoff, then fails" do
    post = scheduled_post([ facebook ])
    target = post.targets.first
    allow(provider).to receive(:publish).and_raise(Social::Provider::Error.new("Try later", transient: true))
    described_class.new(target).publish!
    expect(target.reload).to have_attributes(status: "pending", attempts: 1, error: include("will try again"))
    expect(target.next_attempt_at).to be_within(5.seconds).of(5.minutes.from_now)

    2.times { target.update!(next_attempt_at: 1.minute.ago); described_class.new(target.reload).publish! }
    expect(target.reload).to have_attributes(status: "failed", attempts: 3)
    expect(post.reload).to be_failed
  end

  it "flags accounts whose token stopped working" do
    post = scheduled_post([ facebook ])
    allow(provider).to receive(:publish).and_raise(Social::Provider::Error.new("Session expired", reconnect: true))
    described_class.new(post.targets.first).publish!
    expect(facebook.reload).to be_needs_reconnect
    expect(post.targets.first.reload).to be_failed
  end

  it "never retries a target left mid-publish: it's unknown until someone checks" do
    post = scheduled_post([ facebook, instagram ], photos: 1)
    fb, ig = post.targets.order(:id)
    allow(provider).to receive(:publish).and_return(Social::Provider::PublishResult.new("1", nil))
    described_class.new(fb).publish!
    ig.update_columns(status: "publishing", updated_at: 20.minutes.ago)

    described_class.mark_stuck!
    expect(ig.reload).to be_unknown
    expect(post.reload).to be_partly_failed
    expect(SocialPostTarget.due).not_to include(ig)

    ig.mark_posted!(permalink: "https://instagram.com/p/abc")
    expect(post.reload).to be_published
  end

  it "sends photos as public URLs on the church's website address" do
    post = scheduled_post([ instagram ], photos: 2)
    expect(provider).to receive(:publish) do |_target, photo_urls:|
      expect(photo_urls.size).to eq(2)
      expect(photo_urls).to all(start_with("http://#{church.subdomain}.sites.localhost/rails/active_storage/blobs/"))
      Social::Provider::PublishResult.new("ig-1", nil)
    end
    described_class.new(post.targets.first).publish!
  end
end

RSpec.describe SocialPost do
  let(:facebook) { create(:social_account) }
  let(:instagram) { create(:social_account, :instagram) }

  it "checks each network's rules before scheduling" do
    post = create(:social_post, accounts: [ facebook, instagram ], body: "x" * 2_300)
    expect(post.problems).to include("#{instagram.label} needs a photo", "#{instagram.label} allows 2200 characters (this is 2300)")
    expect { post.schedule!(1.hour.from_now) }.to raise_error(ArgumentError)

    post.targets.find_by(social_account: instagram).update!(caption: "Short for Instagram")
    post.media.attach(io: file_fixture("landscape.png").open, filename: "a.png", content_type: "image/png")
    expect(post.reload.problems).to be_empty
    post.schedule!(1.hour.from_now)
    expect(post.targets.pluck(:status).uniq).to eq([ "pending" ])
    expect(SocialPostTarget.due).to be_empty
    travel(2.hours) { expect(SocialPostTarget.due.count).to eq(2) }

    post.cancel!
    expect(post.targets.pluck(:status).uniq).to eq([ "cancelled" ])
  end
end

RSpec.describe Social::EventPromo do
  include ActiveJob::TestHelper

  it "drafts one promo when a public event is published, and none when turned off" do
    facebook = create(:social_account)
    create(:social_account, :instagram)
    event = create(:event, title: "Fall Festival", visibility: "public", status: "draft")
    create(:event_occurrence, event:, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours)
    perform_enqueued_jobs { event.update!(status: "published") }
    post = SocialPost.find_by!(event:)
    expect(post).to have_attributes(status: "draft", source: "event_promo", link_url: "http://#{church.subdomain}.sites.localhost/e/#{event.slug}")
    expect(post.body).to include("Fall Festival")
    expect(post.accounts).to contain_exactly(facebook) # Instagram needs a photo first

    expect(described_class.new(event).draft!).to eq(post)
    church.update!(social_event_promos: false)
    other = create(:event, visibility: "public", status: "draft").tap { |e| create(:event_occurrence, event: e, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour) }
    perform_enqueued_jobs { other.update!(status: "published") }
    expect(SocialPost.where(event: other)).to be_empty
  end
end

RSpec.describe Social::Connection do
  it "signs the OAuth state and saves every account with fresh tokens" do
    user = create(:user, :church_admin)
    state = described_class.state_for(church:, user:)
    expect(described_class.read_state(state)).to include("church_id" => church.id, "user_id" => user.id)
    expect(described_class.read_state(state + "x")).to be_nil
    travel(20.minutes) { expect(described_class.read_state(state)).to be_nil }

    record = Social::Provider::AccountRecord.new("facebook_page", "p1", "Grace", nil, nil, "tok-1", nil)
    described_class.save!(user_token: "u1", expires_at: 60.days.from_now, meta_user_id: "m1", accounts: [ record ])
    SocialAccount.last.update!(status: "needs_reconnect")
    described_class.save!(user_token: "u2", expires_at: nil, meta_user_id: "m1", accounts: [ record.with(access_token: "tok-2") ])
    expect(SocialAccount.sole).to have_attributes(status: "connected", access_token: "tok-2")
    expect(Integration.find_by!(category: "social").credential(:user_access_token)).to eq("u2")
  end
end
