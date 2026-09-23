require "rails_helper"

RSpec.describe "Pathway" do
  include ActiveJob::TestHelper

  let(:pathway) { Pathway.current }

  context "as staff" do
    before do
      sign_in_as(create(:user, :staff))
      Pathway::Placement.new(pathway).place_everyone!
    end

    it "shows the dashboard" do
      get pathway_path
      expect(response.body).to include("Connect → Grow → Serve", "People at each stage", "Stuck")
    end

    it "edits a stage's rules and re-places everyone" do
      grow = pathway.stages.second
      get edit_pathway_stage_path(grow)
      expect(response.body).to include("pathway_stage[definition][conditions][0][type]")

      expect {
        patch pathway_stage_path(grow), params: { pathway_stage: { name: "Grow", stuck_after_days: 120,
          definition: { match: "all", conditions: { "0" => { type: "group" } } } } }
      }.to have_enqueued_job(PathwayReplacementJob)
      expect(grow.reload).to have_attributes(stuck_after_days: 120, conditions: [ have_attributes(type: "group") ])
    end

    it "previews counts with draft rules" do
      create(:group_membership)
      get preview_pathway_stages_path(stage_id: pathway.stages.second.id), params: { pathway_stage: { definition: { conditions: { "0" => { type: "group" } } } } }
      expect(response.body).to include("With these rules", "Grow")
      counts = Nokogiri::HTML(response.body).css("li").map { |li| li.text.squish }
      expect(counts.size).to eq(3) # only real stages, never a phantom unsaved one
    end

    it "adds and reorders stages" do
      post pathway_stages_path, params: { pathway_stage: { name: "Lead", definition: { conditions: { "0" => { type: "team" } } } } }
      lead = pathway.stages.reload.last
      expect(lead.name).to eq("Lead")
      patch move_pathway_stage_path(lead), params: { position: 2 }
      expect(pathway.stages.reload.map(&:name)).to eq(%w[ Connect Grow Lead Serve ])
    end

    it "renders the condition builder for stage rules" do
      get condition_segments_path(type: "serving", index: 3, prefix: "pathway_stage"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("pathway_stage[definition][conditions][3][times]")
    end

    it "shows a person's stage on their profile" do
      person = create(:person)
      Pathway::Placement.new(pathway).place!(person)
      get person_path(person)
      expect(response.body).to include("Pathway", "Connect", "started at Connect")
    end

    it "filters the map by stage" do
      get map_path(stage_id: pathway.stages.first.id)
      expect(response).to have_http_status(:ok)
    end
  end

  it "lets the care team see the dashboard but not change the rules" do
    sign_in_as(create(:user, :care_team))
    get pathway_path
    expect(response).to have_http_status(:ok)
    get edit_pathway_path
    expect(response).to have_http_status(:forbidden)
  end
end
