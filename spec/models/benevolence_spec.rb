require "rails_helper"

RSpec.describe "Benevolence" do
  let(:household) { create(:household) }
  let(:person) { create(:person, household:) }
  let(:handler) { create(:user, :church_admin) }
  let(:approver) { create(:user, :church_admin) }
  let(:second_approver) { create(:user, :church_admin) }

  before { church.update!(benevolence_approval_threshold_cents: 50_000, benevolence_annual_limit_cents: 100_000, benevolence_approvals_required: 1) }

  describe Benevolence::Decision do
    it "lets one approver decide at or below the threshold, even if they're handling it" do
      kase = create(:benevolence_case, person:, requested_cents: 30_000, created_by: handler)
      kase.decision.record!(user: handler, decision: "approve", amount_cents: 25_000)
      expect(kase.reload).to have_attributes(status: "approved", approved_cents: 25_000, decided_by: handler)
    end

    it "needs approvers not handling the case above the threshold, and the church's number of them" do
      church.update!(benevolence_approvals_required: 2)
      kase = create(:benevolence_case, person:, requested_cents: 80_000, created_by: handler, assigned_to: handler)
      expect(kase.decision.ineligibility(handler)).to include("someone not handling the case")
      expect { kase.decision.record!(user: handler, decision: "approve", amount_cents: 80_000) }.to raise_error(Benevolence::Decision::NotAllowed)

      kase.decision.record!(user: approver, decision: "approve", amount_cents: 80_000)
      expect(kase.reload).to be_under_review
      expect(kase.decision.approvals_needed).to eq(1)
      expect(kase.decision.ineligibility(approver)).to include("already decided")

      kase.decision.record!(user: second_approver, decision: "approve", amount_cents: 60_000)
      expect(kase.reload).to have_attributes(status: "approved", approved_cents: 60_000) # the lowest amount approved
      expect(AuditEvent.where(auditable: kase).pluck(:action)).to include("benevolence.approval_recorded", "benevolence.approved")
    end

    it "denies on any eligible deny, and people without permission can't decide" do
      kase = create(:benevolence_case, person:)
      member = create(:user, :member)
      expect(kase.decision.eligible?(member)).to be(false)
      kase.decision.record!(user: approver, decision: "deny", note: "Outside our policy")
      expect(kase.reload).to have_attributes(status: "denied", decision_note: "Outside our policy")
    end
  end

  describe BenevolenceDisbursement do
    it "only pays approved cases, never more than approved, and fulfils the case when paid" do
      kase = create(:benevolence_case, person:)
      expect(build(:benevolence_disbursement, benevolence_case: kase)).not_to be_valid

      kase.update!(status: "approved", approved_cents: 30_000)
      create(:benevolence_disbursement, benevolence_case: kase, amount_cents: 10_000)
      expect(build(:benevolence_disbursement, benevolence_case: kase, amount_cents: 25_000)).not_to be_valid
      create(:benevolence_disbursement, benevolence_case: kase, amount_cents: 20_000)
      expect(kase.reload).to be_fulfilled
    end
  end

  describe Benevolence::PolicyCheck do
    it "flags the household going over the 12-month limit, repeat requests, and open cases" do
      spouse = create(:person, household:)
      earlier = create(:benevolence_case, person: spouse, status: "approved", approved_cents: 90_000, created_at: 2.months.ago)
      create(:benevolence_disbursement, benevolence_case: earlier, amount_cents: 90_000, paid_on: 2.months.ago.to_date)
      old = create(:benevolence_case, person:, status: "approved", approved_cents: 50_000, created_at: 14.months.ago)
      create(:benevolence_disbursement, benevolence_case: old, amount_cents: 50_000, paid_on: 14.months.ago.to_date)
      create(:benevolence_case, person: spouse) # still open

      kase = create(:benevolence_case, person:, requested_cents: 20_000)
      keys = kase.policy_check.flags.map(&:key)
      expect(keys).to include("over_limit", "repeat", "open_elsewhere")
      expect(kase.policy_check.paid_last_year_cents).to eq(90_000) # the 14-month-old payment doesn't count

      church.update!(benevolence_limit_scope: "person")
      expect(kase.reload.policy_check.flags.map(&:key)).not_to include("over_limit")
    end
  end

  describe "form intake" do
    it "opens a case from a benevolence form, with private answers and no timeline entry or workflow trigger" do
      Form::Starters.install!
      form = Form.find_by!(slug: "help")
      form.publish!
      create(:workflow, :published, trigger: { "type" => "form_submitted", "config" => { "form_id" => create(:form, :published).id } })
      response = Form::Response.new(form, { "first_name" => "Sam", "last_name" => "Ortiz", "email" => "sam@example.com", "need" => "Utilities",
        "summary" => "Power bill", "amount" => "185.50", "circumstances" => "Hours were cut" })
      expect(response).to be_valid
      submission = FormSubmission.build_from(form, response)
      submission.save!

      expect { FormSubmission::Processing.new(submission).process! }.not_to have_enqueued_job(WorkflowTriggerJob)
      kase = BenevolenceCase.last
      expect(kase).to have_attributes(source: "form", need_category: "utilities", requested_cents: 18_550, summary: "Power bill", circumstances: "Hours were cut")
      expect(kase.person).to have_attributes(email: "sam@example.com")
      expect(kase.person.touchpoints).to be_empty
      expect(submission.reload.answers).not_to have_key("circumstances") # encrypted with the sensitive answers
    end
  end
end
