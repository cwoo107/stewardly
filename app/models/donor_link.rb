# "This provider donor is this person." Learned from matches so future gifts match automatically.
class DonorLink < ApplicationRecord
  belongs_to :person
  belongs_to :created_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :provider, :donor_external_id, presence: true
  validates :donor_external_id, uniqueness: { scope: %i[ church_id provider ] }
end
