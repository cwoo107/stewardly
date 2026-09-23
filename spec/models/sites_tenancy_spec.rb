require "rails_helper"

[ Site, SiteDomain, Page, PageRevision ].each do |model|
  RSpec.describe model do
    it_behaves_like "a tenant-scoped model"
  end
end
