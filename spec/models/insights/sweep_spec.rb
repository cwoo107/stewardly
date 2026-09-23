require "rails_helper"

RSpec.describe Insights::Sweep do
  let(:owner) { create(:user, :staff) }
  let(:sweep) { described_class.new(church) }

  it "creates one insight per finding, updates it on later runs, and resolves it when the condition clears" do
    task = create(:task, title: "Order bulletins", owner:, due_on: church.today - 10)
    sweep.run!
    insight = Insight.find_by!(kind: "overdue_task", subject: task)
    expect(insight).to have_attributes(severity: "high", audience_user_ids: [ owner.id ], title: include("10 days overdue"))

    travel(1.day) { sweep.run! }
    expect(Insight.where(kind: "overdue_task").count).to eq(1)
    expect(insight.reload.title).to include("11 days overdue")

    task.update!(status: "done")
    expect(insight.reload).to have_attributes(status: "resolved", resolution: "done")
    create(:task, owner:, due_on: church.today - 2).then { sweep.run! }
    other = Insight.where(kind: "overdue_task").live.sole
    other.subject.update!(due_on: church.today + 5)
    sweep.run!
    expect(other.reload).to have_attributes(status: "resolved", resolution: "cleared")
  end

  it "reopens snoozed insights when the snooze ends and stays quiet about dismissed ones" do
    create(:task, owner:, due_on: church.today - 1)
    sweep.run!
    insight = Insight.live.sole
    insight.snooze!(church.today + 1)
    sweep.run!
    expect(insight.reload).to be_snoozed
    travel(2.days) { sweep.run! }
    expect(insight.reload).to be_open

    insight.dismiss!(by: owner)
    travel(3.days) { sweep.run! }
    expect(Insight.live.count).to eq(0)
  end

  it "finds first-time guests nobody has contacted, and forgets them once someone has" do
    guest = create(:person, first_name: "Rae")
    visit = create(:attendance, person: guest, checked_in_at: 4.days.ago)
    sweep.run!
    expect(Insight.find_by!(kind: "guest_without_follow_up", subject: guest)).to have_attributes(severity: "high")

    guest.touchpoints.create!(kind: :call, summary: "Called Rae", occurred_at: visit.checked_in_at + 1.day)
    sweep.run!
    expect(Insight.live.where(kind: "guest_without_follow_up")).to be_empty
  end

  it "counts queues without exposing private text, for the right permission" do
    create(:benevolence_case, summary: "Secret rent problem")
    sweep.run!
    insight = Insight.find_by!(kind: "queue")
    expect(insight).to have_attributes(audience_permission: "approve_benevolence", title: "1 benevolence request waiting for a decision")
    expect(Insight.visible_to(create(:user, :staff))).not_to include(insight)
    expect(Insight.visible_to(create(:user, :church_admin))).to include(insight)
  end

  it "reports members with no recent contact and groups at capacity" do
    create(:person, membership_status: "member")
    group = create(:group, capacity: 1)
    create(:group_membership, group:)
    sweep.run!
    expect(Insight.find_by!(kind: "no_recent_contact").data).to include("count" => be >= 1, "days" => 60)
    expect(Insight.find_by!(kind: "group_at_capacity", subject: group).title).to include("is full")
  end
end
