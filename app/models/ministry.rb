class Ministry < ApplicationRecord
  acts_as_tenant :church

  has_many :ministry_leaderships, dependent: :delete_all
  has_many :leaders, through: :ministry_leaderships, source: :user
  has_many :groups, dependent: :nullify
  has_many :teams, dependent: :restrict_with_error

  validates :name, presence: true
  validates_uniqueness_to_tenant :name

  scope :alphabetical, -> { order(:name) }
end
