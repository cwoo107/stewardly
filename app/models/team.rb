class Team < ApplicationRecord
  belongs_to :ministry
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :positions, dependent: :destroy
  has_many :team_memberships, dependent: :delete_all
  has_many :people, through: :team_memberships

  validates :name, presence: true, uniqueness: { scope: :ministry_id }

  scope :alphabetical, -> { order(:name) }
end
