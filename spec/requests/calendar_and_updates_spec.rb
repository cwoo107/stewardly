require "rails_helper"

RSpec.describe "Calendar and church updates" do
  it "shows staff a month and an agenda" do
    create(:worship_service, name: "Sunday 9am")
    sign_in_as(create(:user, :staff))
    get calendar_path(month: "2026-10")
    expect(response.body).to include("October 2026", "Sunday 9am")
    get calendar_path(month: "2026-10", view: "agenda")
    expect(response).to have_http_status(:ok)
  end

  it "manages updates" do
    sign_in_as(create(:user, :staff))
    post announcements_path, params: { announcement: { title: "Picnic Sunday", body: "Bring a side", published_at: Time.current } }
    expect(Announcement.sole.author).to be_present
  end

  it "keeps members out of both" do
    sign_in_as(create(:user, :member))
    get calendar_path
    expect(response).to have_http_status(:forbidden)
    get announcements_path
    expect(response).to have_http_status(:forbidden)
  end
end
