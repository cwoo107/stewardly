class Task < ApplicationRecord
  include Positionable

  BOARD_STATUSES = %w[ idea todo in_progress done ].freeze
  DONE_VISIBLE_FOR = 30.days

  belongs_to :project, optional: true
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { idea: "idea", todo: "todo", in_progress: "in_progress", done: "done" }, default: :todo, validate: true
  enum :priority, { low: "low", normal: "normal", high: "high", urgent: "urgent" }, default: :normal, validate: true, prefix: true

  validates :title, presence: true, length: { maximum: 200 }

  positioned within: :status
  before_save :track_completion, if: :status_changed?

  scope :overdue, ->(today) { where.not(status: "done").where(due_on: ...today) }
  scope :on_board, -> { where.not(status: "done").or(where(completed_at: DONE_VISIBLE_FOR.ago..)) }

  # Moves the task into a column at a zero-based index.
  def move_to(status:, position:)
    transaction do
      update!(status:)
      reposition(position)
      reload
    end
  end

  def overdue?(today = church.today)
    due_on.present? && due_on < today && !done?
  end

  private
    def track_completion
      self.completed_at = done? ? (completed_at || Time.current) : nil
    end
end
