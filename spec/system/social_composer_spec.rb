require "rails_helper"

RSpec.describe "Composing a social post" do
  include ActiveJob::TestHelper

  it "writes, previews, schedules, and the sweeper publishes it once" do
    facebook = create(:social_account, name: "Grace Community Church")
    sign_in_as(create(:user, :staff))
    allow_any_instance_of(Social::Providers::Meta).to receive(:publish).and_return(Social::Provider::PublishResult.new("fb-1", "https://facebook.com/fb-1"))

    visit new_social_post_path
    fill_in "Post", with: "Picnic after church this Sunday 🧺"
    check facebook.label
    click_on "Save draft"
    expect(page).to have_content("Draft saved")
    expect(page).to have_content("Picnic after church this Sunday") # the Facebook preview

    fill_in "Schedule for", with: 1.hour.from_now.in_time_zone(church.zone).strftime("%Y-%m-%dT%H:%M")
    click_on "Schedule"
    expect(page).to have_content("Scheduled for")

    travel(2.hours) { perform_enqueued_jobs { SocialPublishSweepJob.perform_now } }
    travel(3.hours) { perform_enqueued_jobs { SocialPublishSweepJob.perform_now } }
    visit current_path
    expect(page).to have_content("See it on Facebook")
    expect(SocialPostTarget.sole).to have_attributes(status: "published", attempts: 1)
  end
end
