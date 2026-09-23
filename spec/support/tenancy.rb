# Every spec runs with a church as the tenant, through ActsAsTenant.test_tenant.
# test_tenant is only a fallback: ActsAsTenant.with_tenant still switches churches,
# and ActsAsTenant::TestTenantMiddleware (config/environments/test.rb) hides it
# during requests so the app resolves the church from the host for real.
RSpec.shared_context "church tenant" do
  let(:church) { create(:church) }

  before { ActsAsTenant.test_tenant = church }
end

RSpec.configure do |config|
  config.include_context "church tenant"

  config.after do
    ActsAsTenant.current_tenant = nil
    ActsAsTenant.test_tenant = nil
  end
end

# Usage: it_behaves_like "a tenant-scoped model"            (factory named after the model)
#        it_behaves_like "a tenant-scoped model", :user_role
RSpec.shared_examples "a tenant-scoped model" do |factory_name = nil|
  let(:factory) { factory_name || described_class.model_name.singular.to_sym }

  it "hides records that belong to another church" do
    elsewhere = ActsAsTenant.with_tenant(create(:church)) { create(factory) }
    here = create(factory)

    expect(described_class.find_by(id: elsewhere.id)).to be_nil
    expect(described_class.where(id: [ here.id, elsewhere.id ])).to contain_exactly(here)
    expect(ActsAsTenant.without_tenant { described_class.exists?(elsewhere.id) }).to be(true)
  end

  it "assigns new records to the current church" do
    expect(create(factory).church).to eq(church)
  end

  it "refuses to query without a current church" do
    ActsAsTenant.test_tenant = nil
    expect { described_class.count }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
  end

  it "has a non-null, indexed church_id" do
    expect(described_class.columns_hash.fetch("church_id").null).to be(false)
    indexed = described_class.connection.indexes(described_class.table_name).any? { |index| index.columns.first == "church_id" }
    expect(indexed).to be(true)
  end
end
