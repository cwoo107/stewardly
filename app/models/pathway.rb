# A church's discipleship pathway: ordered stages people move through (Connect → Grow → Serve).
class Pathway < ApplicationRecord
  acts_as_tenant :church

  has_many :stages, -> { ordered }, class_name: "PathwayStage", dependent: :destroy, inverse_of: :pathway

  validates :name, presence: true

  # The church's pathway, set up with the defaults the first time it's needed.
  def self.current
    first || Pathway::Defaults.install!
  end

  def first_stage = stages.first
  def last_stage = stages.last
end
