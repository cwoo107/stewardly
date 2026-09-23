require "rails_helper"

[ Workflow, WorkflowVersion, WorkflowRun, WorkflowStepExecution, MessageDraft, AiRequest, CampaignExtraRecipient ].each do |model|
  RSpec.describe model do
    it_behaves_like "a tenant-scoped model"
  end
end
