# Where money goes: a giving fund synced from the provider (General, Missions), or a
# manual one. Benevolence funds are offered when recording benevolence payments.
class Fund < ApplicationRecord
  acts_as_tenant :church

  has_many :donations, dependent: :restrict_with_error
  has_many :benevolence_disbursements, dependent: :restrict_with_error

  validates :name, presence: true
  validates :provider, presence: true
  validates :external_id, uniqueness: { scope: %i[ church_id provider ] }, allow_nil: true

  scope :alphabetical, -> { order(:name) }
  scope :active, -> { where(active: true) }
  scope :for_benevolence, -> { active.where(benevolence: true) }

  def manual? = provider == "manual"
end
