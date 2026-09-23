require "rails_helper"

RSpec.describe Volunteering::LoadAssessment do
  let(:today) { Date.new(2026, 10, 4) } # a Sunday
  let(:team) { create(:team) }
  let(:position) { create(:position, team:) }
  let(:person) { create(:person) }

  before do
    church.update!(time_zone: "Central Time (US & Canada)")
    create(:team_membership, team:, person:, created_at: 1.year.ago)
  end

  def served(weeks_ago, status: "accepted")
    date = today - (weeks_ago * 7)
    service = WorshipService.first || create(:worship_service)
    occurrence = service.occurrences.find_by(local_date: date) || create(:service_occurrence, worship_service: service, local_date: date)
    create(:assignment, schedulable: occurrence, position:, person:, status:)
  end

  def assess(**options) = travel_to(today.noon) { described_class.new(people: [ person ], church:).for(person, as_of: today, **options) }

  it "is healthy with a light load" do
    served(0)
    served(3)
    expect(assess).to have_attributes(level: "healthy", consecutive_weeks: 1, per_week: 0.25, teams: 1, weeks_since_served: 0)
  end

  it "is elevated after 4 weeks in a row, and at risk after 6" do
    (0..3).each { |week| served(week) }
    expect(assess).to have_attributes(level: "elevated", consecutive_weeks: 4)
    (4..5).each { |week| served(week) }
    expect(assess.level).to eq("at_risk")
    expect(assess.reasons).to include("6 weeks in a row")
  end

  it "counts teams and frequent declines" do
    3.times { create(:team_membership, person:) }
    expect(assess).to have_attributes(level: "at_risk", reasons: [ "on 4 teams" ])
    TeamMembership.where(person:).where.not(team:).delete_all

    served(1, status: "declined")
    served(2, status: "declined")
    served(4, status: "accepted")
    expect(assess).to have_attributes(level: "elevated", decline_rate: 0.67)
  end

  it "is underused when on a team but not scheduled in 8 weeks" do
    served(10)
    expect(assess).to have_attributes(level: "underused", reasons: [ "not scheduled in 10 weeks" ])
  end

  it "doesn't call a brand-new team member underused" do
    TeamMembership.where(person:).update_all(created_at: 2.weeks.ago)
    expect(travel_to(today.noon) { described_class.new(people: [ person ], church:).for(person, as_of: today) }.level).to eq("healthy")
  end

  it "answers what one more assignment would do" do
    (1..5).each { |week| served(week) }
    expect(assess.level).to eq("elevated")
    expect(assess(extra_date: today).level).to eq("at_risk")
  end

  it "uses the church's thresholds" do
    (0..1).each { |week| served(week) }
    church.update!(volunteer_load_thresholds: { "elevated_consecutive_weeks" => 2 })
    expect(assess.level).to eq("elevated")
  end

  it "loads history in a fixed number of queries for many people" do
    people = create_list(:person, 5)
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      loads = described_class.new(people:, church:)
      people.each { |p| loads.for(p, as_of: today) }
    end
    expect(queries).to be <= 3
  end
end
