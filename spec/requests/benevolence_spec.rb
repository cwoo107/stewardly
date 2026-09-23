require "rails_helper"

RSpec.describe "Benevolence" do
  let(:person) { create(:person, first_name: "Sam") }

  context "on the benevolence team" do
    let(:team_member) { create(:user, role_keys: [ :benevolence_team ]) }

    before { sign_in_as(team_member) }

    it "opens a case, audits every view, and adds notes; approving needs the approve permission" do
      get new_benevolence_case_path(person_id: person.id)
      post benevolence_cases_path, params: { benevolence_case: { person_id: person.id, need_category: "utilities", summary: "Power bill",
        circumstances: "Hours cut", requested: "185.50", assigned_to_id: team_member.id } }
      kase = BenevolenceCase.last
      expect(kase).to have_attributes(requested_cents: 18_550, created_by: team_member, source: "staff")

      expect { get benevolence_case_path(kase) }.to change { AuditEvent.where(action: "benevolence_case.viewed", auditable: kase).count }.by(1)
      expect(response.body).to include("Power bill", "Hours cut", "One approval decides it")
      expect(response.body).not_to include("Approve</button>")

      post benevolence_case_notes_path(kase), params: { benevolence_note: { body: "Called the utility" } }
      expect(kase.notes.last.body).to eq("Called the utility")
      post decide_benevolence_case_path(kase), params: { decision: "approve", amount: "185.50" }
      expect(response).to have_http_status(:forbidden)
    end

    it "only manages benevolence funds" do
      general = create(:fund, name: "General")
      post funds_path, params: { fund: { name: "Care fund", benevolence: "0" } }
      expect(Fund.find_by!(name: "Care fund").benevolence).to be(true)
      get funds_path
      expect(response.body).to include("Care fund")
      expect(response.body).not_to include("General")
      get edit_fund_path(general)
      expect(response).to have_http_status(:not_found)
    end

    it "lists cases without their private text" do
      create(:benevolence_case, person:, summary: "Secret summary", circumstances: "Secret situation")
      get benevolence_cases_path
      expect(response.body).to include("Rent or mortgage for Sam")
      expect(response.body).not_to include("Secret")
    end
  end

  context "as an approver" do
    let(:admin) { create(:user, :church_admin) }

    before { sign_in_as(admin) }

    it "approves, records payments, and closes the case when paid" do
      fund = create(:fund, :benevolence, name: "Care fund")
      kase = create(:benevolence_case, person:, requested_cents: 20_000)
      post decide_benevolence_case_path(kase), params: { decision: "approve", amount: "150", note: "Partial" }
      expect(kase.reload).to have_attributes(status: "approved", approved_cents: 15_000)

      post benevolence_case_disbursements_path(kase), params: { benevolence_disbursement: { amount: "150.00", fund_id: fund.id, paid_on: Date.current,
        method: "check", payee_type: "utility", payee_name: "City Power", reference: "Check 1042" } }
      expect(kase.reload).to be_fulfilled
      expect(kase.disbursements.last).to have_attributes(amount_cents: 15_000, fund:, reference: "Check 1042", recorded_by: admin)

      get report_benevolence_cases_path
      expect(response.body).to include("$150.00", "Rent or mortgage", "Care fund")
      get audit_events_path
      expect(response.body).to include("opened a benevolence case").or include("recorded a benevolence payment")
    end

    it "sets the approval rules in church settings" do
      patch church_settings_path, params: { church: { benevolence_approval_threshold: "750", benevolence_approvals_required: "2",
        benevolence_annual_limit: "1,500.00", benevolence_limit_scope: "person" } }
      expect(church.reload).to have_attributes(benevolence_approval_threshold_cents: 75_000, benevolence_approvals_required: 2,
        benevolence_annual_limit_cents: 150_000, benevolence_limit_scope: "person")
    end

    it "sends benevolence form submissions to their audited case" do
      Form::Starters.install!
      form = Form.find_by!(slug: "help")
      submission = create(:form_submission, form:)
      kase = create(:benevolence_case, person:, form_submission: submission, source: "form")
      get form_submission_path(form, submission)
      expect(response).to redirect_to(benevolence_case_path(kase))
    end
  end

  it "keeps benevolence from staff" do
    sign_in_as(create(:user, :staff))
    kase = create(:benevolence_case, person:)
    get benevolence_cases_path
    expect(response).to have_http_status(:forbidden)
    get benevolence_case_path(kase)
    expect(response).to have_http_status(:forbidden)
    get person_path(person)
    expect(response.body).not_to include("Benevolence")
  end
end
