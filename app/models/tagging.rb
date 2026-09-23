class Tagging < ApplicationRecord
  include AffectsPathway

  belongs_to :tag
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  after_create_commit { Workflow::Events.publish("tag_added", person:, subject: self) }

  validates :tag_id, uniqueness: { scope: :person_id }
end
