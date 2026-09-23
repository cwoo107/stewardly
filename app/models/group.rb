class Group < ApplicationRecord
  include Geocodable

  belongs_to :ministry, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :group_memberships, dependent: :delete_all
  has_many :people, through: :group_memberships
  has_many :join_requests, class_name: "GroupJoinRequest", dependent: :delete_all

  enum :group_type, { small_group: "small_group", bible_study: "bible_study", connection_group: "connection_group", other: "other" },
    default: :small_group, validate: true
  enum :meeting_frequency, { weekly: "weekly", biweekly: "biweekly", monthly: "monthly" }, default: :weekly, validate: true

  validates :name, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :meeting_day, inclusion: { in: 0..6 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  # Nearest first using the GiST index (KNN <->); adds a distance_meters column.
  scope :nearest_to, ->(point) {
    origin = "SRID=4326;#{point.as_text}"
    located
      .select(sanitize_sql_array([ "groups.*, ST_Distance(groups.location, ST_GeogFromText(?)) AS distance_meters", origin ]))
      .order(Arel.sql(sanitize_sql_array([ "groups.location <-> ST_GeogFromText(?)", origin ])))
  }

  def leaders
    people.merge(GroupMembership.leader)
  end

  def distance_miles
    self[:distance_meters] && (self[:distance_meters] / Segment::Condition::METERS_PER_MILE)
  end

  def full?
    capacity.present? && group_memberships.size >= capacity
  end

  def meeting_summary
    parts = [ meeting_frequency.humanize ]
    parts << Date::DAYNAMES[meeting_day] if meeting_day
    parts << meeting_time.strftime("%-l:%M %p") if meeting_time
    parts.join(" · ")
  end
end
