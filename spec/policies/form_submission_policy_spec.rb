require "rails_helper"

RSpec.describe FormSubmissionPolicy do
  let(:general) { create(:form_submission, form: create(:form, :published)) }
  let(:prayer) { create(:form_submission, form: create(:form, :prayer)) }

  it "lets staff read general submissions but not prayer ones" do
    staff = create(:user, :staff)
    expect(described_class.new(staff, general).show?).to be(true)
    expect(described_class.new(staff, prayer).show?).to be(false)
    expect(described_class::Scope.new(staff, FormSubmission).resolve).to contain_exactly(general)
  end

  it "keeps prayer submissions to pastoral staff" do
    pastor = create(:user, :church_admin)
    care = create(:user, :care_team)
    expect(described_class.new(pastor, prayer).show_sensitive?).to be(true)
    expect(described_class.new(care, prayer).show?).to be(false)
    expect(described_class::Scope.new(pastor, FormSubmission).resolve).to contain_exactly(general, prayer)
  end

  it "shows sensitive general answers only to form managers" do
    viewer = create(:user, roles: [ create(:role, permissions: %w[ view_form_submissions ]) ])
    expect(described_class.new(viewer, general).show?).to be(true)
    expect(described_class.new(viewer, general).show_sensitive?).to be(false)
    expect(described_class.new(create(:user, :staff), general).show_sensitive?).to be(true)
  end
end
