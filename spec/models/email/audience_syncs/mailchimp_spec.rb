require "rails_helper"

RSpec.describe Email::AudienceSyncs::Mailchimp do
  # TODO(verify vendor docs): confirm the batch members endpoint and payload shape in the
  # Mailchimp Marketing API reference, then stub that request and assert on it here.
  it "upserts a segment's people into the audience" do
    pending "Verify against the Mailchimp Marketing API docs"
    raise "Stub POST /lists/{list_id} with the documented body and assert it's requested"
  end
end
