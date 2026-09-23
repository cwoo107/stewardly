require "rails_helper"

RSpec.describe Calendar::Feed do
  let(:range) { Date.new(2026, 10, 1)..Date.new(2026, 10, 31) }
  let(:member) { create(:user, :member) }
  let(:staff) { create(:user, :staff) }

  def on(day, hour = 18) = church.zone.local(2026, 10, day, hour)

  before do
    create(:worship_service, name: "Sunday 9am")
    { "Public picnic" => [ "public", "published" ], "Members dinner" => [ "members", "published" ],
      "Staff retreat" => [ "internal", "published" ], "Draft idea" => [ "public", "draft" ] }.each do |title, (visibility, status)|
      create(:event_occurrence, event: create(:event, title:, visibility:, status:), starts_at: on(10), ends_at: on(10, 20))
    end
  end

  it "shows members published member-visible events, services, and their own serving" do
    create(:assignment, person: member.person, schedulable: create(:service_occurrence, local_date: Date.new(2026, 10, 11)))
    titles = described_class.new(viewer: member, range:, audience: :member).items.map(&:title).uniq

    expect(titles).to include("Public picnic", "Members dinner", "Sunday 9am")
    expect(titles.grep(/Serving/)).not_to be_empty
    expect(titles).not_to include("Staff retreat", "Draft idea")
  end

  it "shows staff internal events and drafts to event managers" do
    titles = described_class.new(viewer: staff, range:, audience: :staff).items.map(&:title)
    expect(titles).to include("Staff retreat", "Draft idea")
  end

  it "shows members only the classes they're in" do
    session = create(:course_session, starts_at: on(12), ends_at: on(12, 19))
    other = create(:course_session, starts_at: on(13), ends_at: on(13, 19))
    create(:enrollment, course_offering: session.course_offering, person: member.person)

    kinds = described_class.new(viewer: member, range:, audience: :member).items.select { |i| i.kind == "class" }
    expect(kinds.map(&:local_date)).to eq([ session.local_date ])
    expect(kinds.map(&:local_date)).not_to include(other.local_date)
  end

  it "computes services without saving occurrences" do
    expect { described_class.new(viewer: staff, range:, audience: :staff).items }.not_to change(ServiceOccurrence, :count)
  end
end
