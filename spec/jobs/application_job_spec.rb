require "rails_helper"

RSpec.describe ApplicationJob do
  include ActiveJob::TestHelper

  # Stands in for the real jobs of later phases.
  let(:job_class) do
    Class.new(described_class) do
      def self.name = "TenantProbeJob"

      cattr_accessor :observed

      def perform(person)
        self.class.observed = { tenant: ActsAsTenant.current_tenant, people: Person.count, person: person }
      end
    end
  end

  before { stub_const("TenantProbeJob", job_class) }

  it "runs in the church that enqueued it" do
    person = create(:person)
    ActsAsTenant.with_tenant(create(:church)) { create(:person) }

    ActsAsTenant.with_tenant(church) { TenantProbeJob.perform_later(person) }
    ActsAsTenant.test_tenant = nil # the worker has no ambient tenant

    perform_enqueued_jobs

    expect(TenantProbeJob.observed).to eq(tenant: church, people: 1, person:)
  end
end
