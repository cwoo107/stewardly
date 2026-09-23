require "rails_helper"

RSpec.describe Announcement do
  it_behaves_like "a tenant-scoped model"

  it "shows published, unexpired updates, pinned first" do
    older = create(:announcement, published_at: 2.days.ago)
    pinned = create(:announcement, published_at: 3.days.ago, pinned: true)
    create(:announcement, published_at: 1.day.from_now)
    create(:announcement, published_at: 5.days.ago, expires_on: Date.current - 1)
    create(:announcement, published_at: nil)

    expect(Announcement.current).to eq([ pinned, older ])
  end
end
