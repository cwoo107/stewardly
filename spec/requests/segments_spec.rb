require "rails_helper"

RSpec.describe "Segments" do
  let(:staff) { create(:user, :staff) }
  let(:definition) { { match: "all", conditions: { "0" => { type: "membership_status", statuses: [ "member" ] } } } }

  before do
    create(:person, first_name: "Mia", last_name: "Member", membership_status: "member")
    create(:person, first_name: "Gus", last_name: "Guest")
    sign_in_as(staff)
  end

  it "creates a segment and lists its people" do
    post segments_path, params: { segment: { name: "Members", definition: } }
    segment = Segment.last
    expect(response).to redirect_to(segment)

    get segment_path(segment)
    expect(response.body).to include("Mia Member", "Status is Member")
    expect(response.body).not_to include("Gus Guest")
  end

  it "rejects invalid conditions" do
    post segments_path, params: { segment: { name: "Broken", definition: { conditions: { "0" => { type: "age" } } } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("needs a minimum or maximum age")
  end

  it "previews a count while building" do
    get preview_segments_path, params: { segment: { definition: } }
    expect(response.body).to include("1 person", "Mia Member")
  end

  it "renders a new condition row as a Turbo Stream" do
    create(:tag, name: "Volunteer")
    get condition_segments_path(type: "tag", index: 7), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include("segment[definition][conditions][7][tag_ids][]", "Volunteer")
  end

  it "lets the care team view but not create segments" do
    sign_in_as(create(:user, :care_team))
    get segments_path
    expect(response).to have_http_status(:ok)
    post segments_path, params: { segment: { name: "Nope", definition: } }
    expect(response).to have_http_status(:forbidden)
  end

  it "pre-fills conditions from a link" do
    get new_segment_path(conditions: [ { type: "stuck", value: "yes" } ])
    expect(response.body).to include("Stuck on the pathway", "segment[definition][conditions][0][value]")
  end
end
