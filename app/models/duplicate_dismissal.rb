# Staff decided these two people are different, so the duplicate queue stops pairing them.
class DuplicateDismissal < ApplicationRecord
  belongs_to :person
  belongs_to :other_person, class_name: "Person"
  belongs_to :dismissed_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  before_validation :order_pair
  validates :other_person_id, uniqueness: { scope: :person_id }

  private
    def order_pair
      self.person_id, self.other_person_id = [ person_id, other_person_id ].sort if person_id && other_person_id
    end
end
