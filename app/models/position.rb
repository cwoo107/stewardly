# A role someone can be scheduled into on a team (vocals, drums, greeter).
# Scheduling against positions arrives in Phase 3.
class Position < ApplicationRecord
  belongs_to :team
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :position_qualifications, dependent: :delete_all
  has_many :qualified_people, through: :position_qualifications, source: :person
  has_many :position_needs, dependent: :destroy
  has_many :assignments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :team_id }

  scope :alphabetical, -> { order(:name) }
end
