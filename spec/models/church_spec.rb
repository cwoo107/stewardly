require "rails_helper"

RSpec.describe Church do
  describe "validations" do
    it "is valid from the factory" do
      expect(build(:church)).to be_valid
    end

    it "requires a unique subdomain regardless of case" do
      create(:church, subdomain: "grace")
      expect(build(:church, subdomain: "GRACE")).not_to be_valid
    end

    it "normalizes the subdomain" do
      expect(build(:church, subdomain: "  Grace ").subdomain).to eq("grace")
    end

    it "rejects reserved subdomains" do
      church = build(:church, subdomain: "www")
      expect(church).not_to be_valid
      expect(church.errors[:subdomain]).to include("is reserved")
    end

    it "rejects subdomains that are not valid hostnames" do
      %w[ -grace grace- gr_ace gr.ace ].each do |subdomain|
        expect(build(:church, subdomain:)).not_to be_valid, "expected #{subdomain.inspect} to be invalid"
      end
    end

    it "requires a recognized time zone" do
      expect(build(:church, time_zone: "Mars/Olympus")).not_to be_valid
      expect(build(:church, time_zone: "Pacific Time (US & Canada)")).to be_valid
    end
  end

  describe "time in the church's zone" do
    it "computes today in the church's time zone, not UTC" do
      church = build(:church, time_zone: "Central Time (US & Canada)")

      travel_to Time.utc(2026, 9, 21, 3, 0) do # 10pm on Sep 20 in Chicago
        expect(church.today).to eq(Date.new(2026, 9, 20))
        expect(church.now.utc_offset).to eq(-5.hours)
      end
    end
  end

  describe "#host" do
    it "hangs the subdomain off the app domain" do
      expect(build(:church, subdomain: "grace").host).to eq("grace.#{Rails.configuration.x.app_domain}")
    end
  end

  describe "auditing" do
    it "records settings changes" do
      church.update!(name: "Grace Downtown", time_zone: "Eastern Time (US & Canada)")

      event = AuditEvent.last
      expect(event).to have_attributes(action: "church.settings_updated", auditable: church)
      expect(event.metadata.keys).to contain_exactly("name", "time_zone")
    end

    it "does not audit unrelated saves" do
      expect { church.touch }.not_to change(AuditEvent, :count)
    end
  end
end
