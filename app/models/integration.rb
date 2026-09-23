# A church's connection to an outside service, with its credentials encrypted.
# One active integration per category.
class Integration < ApplicationRecord
  CATEGORIES = {
    "email_delivery" => { "postmark" => "Postmark", "ses" => "Amazon SES" },
    "email_audience_sync" => { "mailchimp" => "Mailchimp" },
    "giving" => { "tithely" => "Tithe.ly" },
    "social" => { "meta" => "Facebook and Instagram" }
  }.freeze

  # Which credentials and settings each provider asks for (all strings).
  FIELDS = {
    "postmark" => { credentials: %w[ server_token webhook_password ], settings: %w[ broadcast_stream transactional_stream ] },
    "ses" => { credentials: %w[ access_key_id secret_access_key ], settings: %w[ region configuration_set ] },
    "mailchimp" => { credentials: %w[ api_key ], settings: %w[ server_prefix list_id segment_id ] },
    # TODO(verify vendor docs): which credentials Tithe.ly's API actually uses.
    "tithely" => { credentials: %w[ api_key webhook_secret ], settings: %w[ organization_id ] },
    # Connected by OAuth, not a form: credentials hold the long-lived user token.
    "meta" => { credentials: %w[ user_access_token ], settings: %w[ meta_user_id ] }
  }.freeze

  acts_as_tenant :church

  has_many :webhook_events, dependent: :delete_all
  has_many :social_accounts, dependent: :destroy

  serialize :credentials, coder: JSON
  encrypts :credentials

  has_secure_token :webhook_token

  enum :status, { active: "active", disabled: "disabled" }, default: :active, validate: true

  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :category, uniqueness: { scope: :church_id, conditions: -> { active }, message: "already has a connected provider" }, if: :active?
  validate :provider_fits_category

  def self.label_for(provider) = CATEGORIES.values.reduce(:merge).fetch(provider, provider.to_s.humanize)

  def credential(key) = credentials.to_h[key.to_s].presence
  def setting(key) = settings.to_h[key.to_s].presence
  def label = self.class.label_for(provider)

  # The adapter that talks to this provider.
  def adapter
    case provider
    when "postmark" then Email::Providers::Postmark.new(self)
    when "ses" then Email::Providers::Ses.new(self)
    when "mailchimp" then Email::AudienceSyncs::Mailchimp.new(self)
    when "tithely" then Giving::Providers::Tithely.new(self)
    when "meta" then Social::Providers::Meta.new(self)
    end
  end

  private
    def provider_fits_category
      errors.add(:provider, "isn't available for #{category.to_s.humanize.downcase}") unless CATEGORIES.fetch(category, {}).key?(provider)
    end
end
