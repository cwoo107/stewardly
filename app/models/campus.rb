class Campus < ApplicationRecord
  include ExpiresSiteCache
  include Geocodable

  acts_as_tenant :church

  validates :name, presence: true
  validates :is_default, uniqueness: { scope: :church_id }, if: :is_default?

  before_destroy :keep_default_campus

  scope :ordered, -> { order(is_default: :desc, name: :asc) }

  def self.default
    find_by(is_default: true)
  end

  private
    def keep_default_campus
      return unless is_default?

      errors.add(:base, "The default campus can't be deleted")
      throw :abort
    end
end
