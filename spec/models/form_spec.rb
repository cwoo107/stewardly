require "rails_helper"

RSpec.describe Form do
  it_behaves_like "a tenant-scoped model"

  it "derives a URL-safe slug from the name, unique per church" do
    expect(create(:form, name: "Connect Card!").slug).to eq("connect-card")
    expect(build(:form, name: "Other", slug: "connect-card")).not_to be_valid
    expect(ActsAsTenant.with_tenant(create(:church)) { build(:form, slug: "connect-card").valid? }).to be(true)
  end

  it "needs fields before publishing" do
    form = create(:form)
    expect { form.publish! }.to raise_error(ActiveRecord::RecordInvalid, /at least one field/)
  end

  it "needs a prayer field before a prayer form can publish" do
    form = create(:form, :prayer)
    form.fields.create!(label: "Name", field_type: "text")
    expect { form.publish! }.to raise_error(ActiveRecord::RecordInvalid, /goes to the prayer request/)

    form.fields.create!(label: "Request", field_type: "paragraph", maps_to: "prayer_request.body")
    form.fields.reset
    expect { form.publish! }.to change { form.reload.status }.to("published")
  end

  it "can't be deleted once it has submissions" do
    form = create(:form, :published)
    create(:form_submission, form:)
    expect(form.destroy).to be(false)
  end
end
