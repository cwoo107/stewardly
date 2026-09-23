require "rails_helper"

RSpec.describe "Pathway jobs" do
  include ActiveJob::TestHelper

  it "re-places a person when a fact a rule reads changes" do
    person = create(:person)
    expect { create(:group_membership, person:) }.to have_enqueued_job(PathwayPlacementJob).with(person)
    expect { create(:enrollment, person:) }.to have_enqueued_job(PathwayPlacementJob).with(person)
    expect { create(:team_membership, person:) }.to have_enqueued_job(PathwayPlacementJob).with(person)
    expect { create(:attendance, person:) }.to have_enqueued_job(PathwayPlacementJob).with(person)
    expect { create(:tagging, person:) }.to have_enqueued_job(PathwayPlacementJob).with(person)
    expect { person.update!(membership_status: "member") }.to have_enqueued_job(PathwayPlacementJob).with(person)
  end

  it "places the person" do
    person = create(:person)
    create(:group_membership, person:)
    PathwayPlacementJob.perform_now(person)
    expect(person.reload.pathway_placement.pathway_stage.name).to eq("Grow")
  end

  it "sweeps each church at 3am local time only" do
    create(:person)
    ActsAsTenant.test_tenant = nil
    travel_to(church.zone.local(2026, 10, 5, 3, 25)) { PathwaySweepJob.perform_now }
    expect(ActsAsTenant.with_tenant(church) { PathwayPlacement.count }).to eq(1)

    ActsAsTenant.with_tenant(church) { PathwayPlacement.delete_all }
    travel_to(church.zone.local(2026, 10, 5, 9)) { PathwaySweepJob.perform_now }
    expect(ActsAsTenant.with_tenant(church) { PathwayPlacement.count }).to eq(0)
  end

  it "announces stage changes for workflows" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("pathway.stage_changed") { |*, payload| events << payload[:transition] }
    Pathway::Placement.new(Pathway.current).place!(create(:person))
    expect(events.size).to eq(1)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
