# A kind of email people can choose to get (Church news, Kids ministry, Events).
class EmailTopic < ApplicationRecord
  acts_as_tenant :church

  has_many :email_preferences, dependent: :delete_all
  has_many :campaigns, dependent: :restrict_with_error

  validates :name, presence: true
  validates_uniqueness_to_tenant :name

  scope :alphabetical, -> { order(:name) }

  # The church's everyday topic, created the first time it's needed.
  def self.default!
    order(:created_at).first || create!(name: "Church news", description: "Updates, events, and news from church.")
  end

  def subscribed?(person)
    preference = person.email_preferences.find { |p| p.email_topic_id == id }
    preference ? preference.subscribed : default_subscribed
  end
end
