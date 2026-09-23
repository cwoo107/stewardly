# Operates the SaaS. Not tenant-scoped and never linked to a Person:
# platform admins sign in on the bare app domain only.
class PlatformAdmin < ApplicationRecord
  has_secure_password
  has_many :platform_sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
