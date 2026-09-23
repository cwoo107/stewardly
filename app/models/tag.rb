class Tag < ApplicationRecord
  COLORS = %w[ gray cyan green amber rose violet ].freeze

  acts_as_tenant :church

  has_many :taggings, dependent: :delete_all
  has_many :people, through: :taggings

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true, length: { maximum: 50 }
  validates_uniqueness_to_tenant :name
  validates :color, inclusion: { in: COLORS }

  scope :alphabetical, -> { order(:name) }
end
