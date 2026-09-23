require "rails_helper"

[ Fund, Donation, DonorLink, GivingSyncRun, BenevolenceCase, BenevolenceNote, BenevolenceApproval, BenevolenceDisbursement ].each do |model|
  RSpec.describe model do
    it_behaves_like "a tenant-scoped model"
  end
end

RSpec.describe "Encrypted giving and benevolence text" do
  def raw(model, id, column) = model.connection.select_value("SELECT #{column} FROM #{model.table_name} WHERE id = #{id}").to_s

  it "never stores private text in plain text" do
    kase = create(:benevolence_case, summary: "Rent is late", circumstances: "Lost my job in May", decision_note: "Approved half")
    note = create(:benevolence_note, benevolence_case: kase, body: "Landlord called")
    payment = create(:benevolence_disbursement, reference: "Check 1042")
    donation = create(:donation, donor_name: "Ada Lovelace", donor_email: "ada@example.com")

    expect(raw(BenevolenceCase, kase.id, "summary")).not_to include("Rent is late")
    expect(raw(BenevolenceCase, kase.id, "circumstances")).not_to include("Lost my job")
    expect(raw(BenevolenceCase, kase.id, "decision_note")).not_to include("Approved half")
    expect(raw(BenevolenceNote, note.id, "body")).not_to include("Landlord")
    expect(raw(BenevolenceDisbursement, payment.id, "reference")).not_to include("1042")
    expect(raw(Donation, donation.id, "donor_email")).not_to include("ada@")
    expect(kase.reload.circumstances).to eq("Lost my job in May")
  end
end
