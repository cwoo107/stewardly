require "rails_helper"

RSpec.describe Site do
  let!(:site) { Site.current }

  it "starts every church with the six starter pages, unpublished" do
    expect(site.pages.pluck(:slug)).to eq([ "", "about", "events", "groups", "give", "contact" ])
    expect(site.pages.where.not(published_at: nil)).to be_empty
    expect(site).not_to be_published
  end

  it "is found by its sites-domain host or a verified custom domain, never an unverified one" do
    expect(described_class.for_host("#{church.subdomain}.sites.localhost")).to eq(site)
    expect(described_class.for_host("nope.sites.localhost")).to be_nil
    domain = create(:site_domain, site:, hostname: "www.gracechurch.org")
    expect(described_class.for_host("www.gracechurch.org")).to be_nil
    domain.update!(status: "verified")
    expect(described_class.for_host("WWW.GraceChurch.org.")).to eq(site)
  end

  it "won't take our own domains or another church's domain" do
    expect(build(:site_domain, hostname: "grace.sites.localhost")).not_to be_valid
    other = ActsAsTenant.with_tenant(create(:church)) { create(:site_domain, site: Site.current, hostname: "www.taken.org") }
    expect(other).to be_persisted
    expect(build(:site_domain, site:, hostname: "https://www.taken.org/")).not_to be_valid
  end

  describe Site::DnsCheck do
    def resolver(cname: [], a: [])
      double(getresources: nil).tap do |dns|
        allow(dns).to receive(:getresources).with(anything, Resolv::DNS::Resource::IN::CNAME).and_return(cname.map { |n| double(name: Resolv::DNS::Name.create("#{n}.")) })
        allow(dns).to receive(:getresources).with(anything, Resolv::DNS::Resource::IN::A).and_return(a.map { |ip| double(address: ip) })
      end
    end

    it "verifies a CNAME to our target, or apex A records that are all ours" do
      expect(described_class.new("www.x.org", resolver: resolver(cname: [ "domains.sites.localhost" ])).call.ok).to be(true)
      expect(described_class.new("www.x.org", resolver: resolver(cname: [ "elsewhere.net" ])).call.message).to include("elsewhere.net")
      allow(Rails.configuration.x).to receive(:sites_apex_ips).and_return([ "203.0.113.10" ])
      expect(described_class.new("x.org", resolver: resolver(a: [ "203.0.113.10" ])).call.ok).to be(true)
      expect(described_class.new("x.org", resolver: resolver(a: [ "203.0.113.10", "198.51.100.1" ])).call.ok).to be(false)
      expect(described_class.new("x.org", resolver: resolver).call.message).to include("No DNS records")
    end
  end
end

RSpec.describe Page do
  let(:site) { Site.current }
  let(:page) { site.pages.find_by!(slug: "about") }

  it "publishes the draft, keeps revisions, and can discard or restore" do
    original = page.draft_sections
    page.publish!
    expect(page).to have_attributes(published_sections: original, unpublished_changes?: false)
    page.add_section!("call_to_action")
    expect(page).to be_unpublished_changes
    expect(page.published_sections).to eq(original)

    page.discard_draft!
    expect(page.draft_sections).to eq(original)
    page.add_section!("faq")
    page.publish!
    page.restore!(page.revisions.last)
    expect(page.draft_sections).to eq(original)
    expect(page.revisions.count).to eq(2)
  end

  it "validates slugs and keeps site paths free" do
    expect(build(:page, site:, slug: "f")).not_to be_valid
    expect(build(:page, site:, slug: "about")).not_to be_valid
    expect(build(:page, site:, slug: "Our Ministries").tap(&:valid?).slug).to eq("our-ministries")
  end

  it "clears the site's cache when published" do
    expect { page.publish! }.to change { site.reload.content_version }.by(1)
  end
end
