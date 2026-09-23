class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :tag_id, uniqueness: { scope: :person_id }
end
