require "rails_helper"

[ Insight, DailyBrief, ReportConversation, ReportMessage, SavedReport ].each do |model|
  RSpec.describe model do
    it_behaves_like "a tenant-scoped model"
  end
end
