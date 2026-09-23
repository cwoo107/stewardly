require "rails_helper"

RSpec.describe Scheduling::Candidates do
  let(:team) { create(:team) }
  let(:position) { create(:position, team:) }
  let(:service) { create(:worship_service) }
  let(:occurrence) { create(:service_occurrence, worship_service: service) }
  let!(:ann) { member("Ann") }
  let!(:ben) { member("Ben") }
  let!(:cal) { member("Cal") }

  def member(name, **attributes)
    create(:person, first_name: name, last_name: "Volunteer").tap { |person| create(:team_membership, team:, person:, **attributes) }
  end

  def names(candidates) = candidates.map { |candidate| candidate.person.first_name }

  def served(person, weeks_ago, status: "accepted", position: self.position)
    date = occurrence.local_date - (weeks_ago * 7)
    past = service.occurrences.find_by(local_date: date) || create(:service_occurrence, worship_service: service, local_date: date)
    create(:assignment, schedulable: past, position:, person:, status:)
  end

  it "ranks by fewest recent assignments, then fewest declines, then longest since serving" do
    served(ann, 1)
    served(ann, 2)
    served(ben, 1, status: "declined")
    served(cal, 12)

    candidates = described_class.new(occurrence:, position:).all
    expect(names(candidates)).to eq(%w[ Cal Ben Ann ])
    expect(candidates.first.reasons).to include("hasn't served in 8 weeks")
    expect(candidates.second.reasons).to include("declined 1 recently")
  end

  it "only offers qualified people when a position lists qualifications" do
    create(:position_qualification, position:, person: ben)
    expect(names(described_class.new(occurrence:, position:).all)).to eq(%w[ Ben ])
  end

  it "leaves out people blocked out, already on this occurrence, or at their monthly maximum" do
    create(:blockout, person: ann, starts_on: occurrence.local_date, ends_on: occurrence.local_date)
    create(:assignment, schedulable: occurrence, position: create(:position, team:), person: ben)
    cal.team_memberships.sole.update!(max_per_month: 1)
    create(:assignment, schedulable: create(:service_occurrence, worship_service: create(:worship_service), local_date: occurrence.local_date.beginning_of_month),
      position:, person: cal)

    expect(described_class.new(occurrence:, position:).all).to be_empty
  end

  it "flags people serving elsewhere that day, and best skips them" do
    elsewhere = create(:service_occurrence, worship_service: create(:worship_service, name: "11am"), local_date: occurrence.local_date)
    create(:assignment, schedulable: elsewhere, person: ann)

    candidates = described_class.new(occurrence:, position:)
    flagged = candidates.all.find { |c| c.person == ann }
    expect(flagged).to be_conflict
    expect(flagged.reasons.last).to include("also scheduled: 11am")
    expect(names(candidates.best(3))).to eq(%w[ Ben Cal ])
  end
end
