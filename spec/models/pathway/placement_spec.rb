require "rails_helper"

RSpec.describe Pathway::Placement do
  let(:pathway) { Pathway.current }
  let(:connect) { pathway.stages.first }
  let(:grow) { pathway.stages.second }
  let(:serve) { pathway.stages.third }
  let(:placement) { described_class.new(pathway) }

  let!(:guest) { create(:person, first_name: "Guest") }
  let!(:grower) { create(:person, first_name: "Grower").tap { |p| create(:group_membership, person: p) } }
  let!(:server) do
    create(:person, first_name: "Server").tap do |person|
      team = create(:team)
      create(:team_membership, team:, person:)
      past = create(:service_occurrence, local_date: church.today - 14)
      create(:assignment, schedulable: past, position: create(:position, team:), person:, status: "accepted")
    end
  end

  def stage_of(person) = person.reload.pathway_placement.pathway_stage

  it "places everyone at the highest stage whose rules they meet" do
    placement.place_everyone!
    expect([ stage_of(guest), stage_of(grower), stage_of(server) ]).to eq([ connect, grow, serve ])
    expect(PathwayTransition.placed.count).to eq(3)
  end

  it "counts a class as growing" do
    create(:enrollment, person: guest)
    placement.place!(guest)
    expect(stage_of(guest)).to eq(grow)
  end

  it "doesn't count someone on a team who hasn't served lately as serving" do
    Assignment.where(person: server).update_all(local_date: church.today - 90)
    placement.place!(server)
    expect(stage_of(server)).to eq(connect)
  end

  it "records forward moves, and moves people back when the facts lapse" do
    placement.place_everyone!
    create(:group_membership, person: guest)
    placement.place!(guest)
    expect(guest.pathway_transitions.first).to have_attributes(from_stage: connect, to_stage: grow, direction: "forward")

    GroupMembership.where(person: guest).destroy_all
    placement.place!(guest)
    expect(stage_of(guest)).to eq(connect)
    expect(guest.pathway_transitions.first.direction).to eq("back")
  end

  it "changes nothing when repeated" do
    placement.place_everyone!
    expect { placement.place_everyone! }.not_to change(PathwayTransition, :count)
  end

  it "agrees between one person and everyone" do
    placement.place!(server)
    solo = stage_of(server)
    placement.place_everyone!
    expect(stage_of(server)).to eq(solo)
  end

  it "dates a first Connect placement from when the person was added" do
    guest.update_column(:created_at, 200.days.ago)
    placement.place!(guest)
    expect(guest.reload.pathway_placement.entered_at).to be_within(1.second).of(200.days.ago)
  end

  it "previews stage counts with changed rules, without saving" do
    counts = placement.preview(grow.id => { match: "all", conditions: [ { type: "tag", tag_ids: [ create(:tag).id ] } ] })
    expect(counts.transform_keys(&:name)).to eq("Connect" => 2, "Grow" => 0, "Serve" => 1)
    expect(PathwayPlacement.count).to eq(0)
  end

  it "ignores unsaved stages built on the pathway" do
    pathway.stages.new(name: "Draft")
    expect(described_class.new(pathway).preview.keys.map(&:name)).to eq(%w[ Connect Grow Serve ])
  end

  it "drops merged people" do
    placement.place!(guest)
    guest.update!(merged_into: grower)
    placement.place!(guest)
    expect(guest.reload.pathway_placement).to be_nil
  end
end
