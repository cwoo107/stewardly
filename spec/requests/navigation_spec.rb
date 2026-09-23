require "rails_helper"

RSpec.describe "Sidebar navigation" do
  before { sign_in_as(create(:user, :church_admin)) }

  def section(key) = Nokogiri::HTML(response.body).at_css("aside details[data-key='#{key}']")

  it "opens only the section holding the current page and highlights its link" do
    get attendance_counts_path
    expect(section("attendance")["open"]).not_to be_nil
    expect(section("people")["open"]).to be_nil
    active = Nokogiri::HTML(response.body).css("aside a.font-semibold").map(&:text)
    expect(active).to eq([ "Enter counts" ])
  end

  it "keeps every section collapsed on the dashboard" do
    get root_path
    expect(Nokogiri::HTML(response.body).css("aside details[open]")).to be_empty
  end

  it "leaves out sections with nothing the user may open" do
    sign_in_as(create(:user, :care_team))
    get prayer_requests_path
    headings = Nokogiri::HTML(response.body).css("aside details summary").map { |s| s.text.strip }
    expect(headings).to include("People", "Care & work")
    expect(headings).not_to include("Admin", "Attendance")
  end

  it "orders sections from people to admin, and puts the member area link above sign out" do
    sign_in_as(create(:user, :church_admin))
    get root_path
    aside = Nokogiri::HTML(response.body).at_css("aside")
    expect(aside.css("nav > div:first-child a").map { |a| a.text.strip }).to eq(%w[ Dashboard Insights Calendar ])
    expect(aside.css("details summary").map { |s| s.text.strip }).to eq([ "People", "Care & work", "Organization", "Serving & events",
      "Attendance", "Giving", "Email", "Social", "Website", "Automation", "Reports", "Admin" ])
    footer = aside.css("div.border-t").last
    expect(footer.css("a, button").map { |el| el.text.strip }).to eq([ "Log into member area", "Sign out" ])
  end
end
