class EmailPreference < ApplicationRecord
  belongs_to :person
  belongs_to :email_topic
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :email_topic_id, uniqueness: { scope: :person_id }
end
