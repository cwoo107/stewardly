class CourseSession < ApplicationRecord
  belongs_to :course_offering, inverse_of: :sessions
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :session_attendances, dependent: :delete_all

  validates :starts_at, :ends_at, presence: true

  before_validation { self.local_date = starts_at.in_time_zone(church.zone).to_date if starts_at && church }

  delegate :title, to: :course_offering

  def present?(enrollment)
    session_attendances.any? { |attendance| attendance.enrollment_id == enrollment.id && attendance.present }
  end
end
