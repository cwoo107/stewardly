require "rails_helper"

RSpec.describe Form::Starters do
  it "installs publishable draft connect and prayer forms once" do
    described_class.install!
    described_class.install!

    expect(Form.pluck(:slug, :status)).to contain_exactly([ "connect", "draft" ], [ "prayer", "draft" ])
    Form.find_each { |form| expect { form.publish! }.not_to raise_error }
    expect(Form.find_by!(slug: "prayer").field_for("prayer_request.body")).to be_sensitive
  end
end
