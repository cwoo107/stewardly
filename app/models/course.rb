class Course < ApplicationRecord
  belongs_to :ministry, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :offerings, -> { order(:starts_on) }, class_name: "CourseOffering", dependent: :destroy, inverse_of: :course

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }
end
