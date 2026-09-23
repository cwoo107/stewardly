# A Facebook Page or Instagram business account a church can post to. The token is
# the page's own token (Instagram posts use the linked Page's token), encrypted.
class SocialAccount < ApplicationRecord
  NETWORKS = { "facebook_page" => "Facebook", "instagram" => "Instagram" }.freeze

  belongs_to :integration
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :targets, class_name: "SocialPostTarget", dependent: :restrict_with_error

  encrypts :access_token

  enum :status, { connected: "connected", needs_reconnect: "needs_reconnect", disconnected: "disconnected" }, default: :connected, validate: true

  validates :network, inclusion: { in: NETWORKS.keys }
  validates :external_id, :name, presence: true
  validates :external_id, uniqueness: { scope: %i[ church_id network ] }

  scope :usable, -> { connected }
  scope :alphabetical, -> { order(:network, :name) }

  def network_label = NETWORKS.fetch(network)
  def instagram? = network == "instagram"
  def label = "#{network_label}: #{handle.present? ? "@#{handle}" : name}"
  def provider = integration.adapter
end
