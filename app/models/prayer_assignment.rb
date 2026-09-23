class PrayerAssignment < ApplicationRecord
  belongs_to :prayer_request
  belongs_to :user
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :user_id, uniqueness: { scope: :prayer_request_id, message: "is already assigned" }
end
