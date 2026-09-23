require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let(:session) { create(:session, user:) }

  it "connects a user on their church's subdomain" do
    cookies.signed[:session_id] = session.id
    connect "/cable", headers: { "HOST" => church.host }
    expect(connection.current_user).to eq(user)
    expect(connection.current_church).to eq(church)
  end

  it "rejects the session on another church's subdomain" do
    cookies.signed[:session_id] = session.id
    other = create(:church, subdomain: "elsewhere")
    expect { connect "/cable", headers: { "HOST" => other.host } }.to have_rejected_connection
  end

  it "rejects unknown subdomains" do
    expect { connect "/cable", headers: { "HOST" => "nowhere.#{Rails.configuration.x.app_domain}" } }.to have_rejected_connection
  end
end
