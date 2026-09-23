require "rails_helper"

RSpec.describe Segment::Condition, "for courses, attendance, serving, and the pathway" do
  def people(*conditions) = Segment::Query.new(conditions:).people

  let!(:ann) { create(:person, first_name: "Ann") }
  let!(:ben) { create(:person, first_name: "Ben") }

  it "matches enrollment and completion" do
    offering = create(:course_offering)
    create(:enrollment, course_offering: offering, person: ann)
    create(:enrollment, person: ben, status: "completed")
    expect(people({ type: "course" })).to contain_exactly(ann, ben)
    expect(people({ type: "course", operator: "completed" })).to contain_exactly(ben)
    expect(people({ type: "course", course_ids: [ offering.course_id ] })).to contain_exactly(ann)
  end

  it "matches check-ins in a window" do
    service = create(:worship_service)
    2.times { |i| create(:attendance, person: ann, service_occurrence: create(:service_occurrence, worship_service: service, local_date: church.today - (i * 7))) }
    create(:attendance, person: ben, service_occurrence: create(:service_occurrence, worship_service: service, local_date: church.today - 100))
    expect(people({ type: "attendance", times: 2, days: 30 })).to contain_exactly(ann)
  end

  it "matches accepted serving in a window" do
    create(:assignment, person: ann, status: "accepted", schedulable: create(:service_occurrence, local_date: church.today - 7))
    create(:assignment, person: ben, status: "declined", schedulable: create(:service_occurrence, local_date: church.today - 7))
    expect(people({ type: "serving", times: 1, days: 30 })).to contain_exactly(ann)
  end

  it "matches pathway stage and stuck status" do
    pathway = Pathway.current
    create(:pathway_placement, person: ann, pathway_stage: pathway.stages.first, entered_at: 200.days.ago)
    create(:pathway_placement, person: ben, pathway_stage: pathway.stages.second, entered_at: 1.day.ago)
    expect(people({ type: "pathway_stage", stage_ids: [ pathway.stages.second.id ] })).to contain_exactly(ben)
    expect(people({ type: "stuck", value: "yes" })).to contain_exactly(ann)
    expect(people({ type: "stuck", value: "no" })).to contain_exactly(ben)
  end
end
