require "rails_helper"
Rails.root.glob("spec/mailers/previews/*_preview.rb").each { |file| require file }

# Every mailer has a preview, and every preview renders against real records.
RSpec.describe "Mailer previews" do
  before do
    church.update!(subdomain: "grace", contact_email: "office@grace.test") # leader emails fall back to the office
    assignment = create(:assignment, person: create(:person, email: "vol@example.com"))
    assignment.update!(status: "accepted")
    create(:registration, person: create(:person, email: "reg@example.com"))
    create(:enrollment, person: create(:person, email: "class@example.com"))
    create(:group_join_request, person: create(:person, email: "join@example.com"))
    create(:person, email: "newcomer@example.com")
  end

  ActionMailer::Preview.all.each do |preview|
    preview.emails.each do |email|
      it "renders #{preview.preview_name}##{email}" do
        message = preview.call(email)
        expect(message.to).to be_present
        expect(message.body.encoded).to include("http://grace.localhost/")
      end
    end
  end
end
