# Something that needs attention, found by a nightly check (Insights::Detectors). Plain
# Ruby finds these; the daily brief ranks and explains them.
class Insight < ApplicationRecord
  SEVERITY_WEIGHTS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
  LIVE = %w[ open snoozed ].freeze

  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :person, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true
  belongs_to :task, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { open: "open", snoozed: "snoozed", resolved: "resolved", dismissed: "dismissed" }, default: :open, validate: true
  enum :severity, { high: "high", medium: "medium", low: "low" }, validate: true, prefix: true

  validates :kind, :title, :fingerprint, :audience_permission, presence: true

  scope :live, -> { where(status: LIVE) }
  scope :most_severe_first, -> { order(Arel.sql("CASE severity WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END"), detected_at: :asc) }
  scope :mine, ->(user) { where("? = ANY(audience_user_ids)", user.id) }

  # Insights a user may see: ones for a permission they have, or ones that are theirs directly.
  def self.visible_to(user)
    permissions = Permission.keys.select { |key| user.can?(key) }
    where(audience_permission: permissions).or(mine(user))
  end

  def live? = status.in?(LIVE)
  def mine?(user) = audience_user_ids.include?(user.id)
  def label = Insights::Sweep.label_for(kind)
  def age_days(today = church.today) = (today - detected_at.in_time_zone(church.zone).to_date).to_i

  def resolve!(by: Current.user, resolution: "done")
    update!(status: :resolved, resolution:, resolved_by: by, resolved_at: Time.current, snoozed_until: nil)
  end

  def dismiss!(by: Current.user)
    update!(status: :dismissed, resolution: "dismissed", resolved_by: by, resolved_at: Time.current, snoozed_until: nil)
  end

  def snooze!(until_date)
    update!(status: :snoozed, snoozed_until: until_date)
  end

  # Turns it into a task; the insight resolves when the task is done.
  def assign_as_task!(owner:, by: Current.user)
    transaction do
      task = Task.create!(title: title.first(200), owner:, created_by: by, due_on: church.today + (severity_high? ? 1 : 3),
        priority: severity_high? ? "high" : "normal",
        notes: [ detail, (action_path && "Start here: #{Email::Tracking.base_url(church)}#{action_path}") ].compact_blank.join("\n\n"))
      update!(task:, status: :snoozed, snoozed_until: church.today + 7)
      task
    end
  end
end
