require "rails_helper"

# Phase 6 models: each is scoped to one church.
[ EmailTopic, EmailPreference, EmailTemplate, SectionDefinition, Campaign, Delivery, Suppression, Integration, WebhookEvent ].each do |model|
  RSpec.describe model do
    it_behaves_like "a tenant-scoped model"
  end
end
