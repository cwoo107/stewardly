class BenevolenceNote < ApplicationRecord
  belongs_to :benevolence_case
  belongs_to :author, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  encrypts :body

  validates :body, presence: true
end
