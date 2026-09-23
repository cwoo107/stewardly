# A report someone kept: the tool calls behind an answer (or a Metrics run). Re-running
# executes the same calls again, so the numbers are fresh and don't depend on AI.
class SavedReport < ApplicationRecord
  belongs_to :user
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :title, presence: true
  validate :has_tool_calls

  scope :pinned, -> { where(pinned: true) }
  scope :recent_first, -> { order(updated_at: :desc) }

  def rerun!(user: self.user)
    results = tool_calls.map { |call| Reports::Execution.run(call["name"], call["arguments"], user:, church:) }
    update!(last_result: results, last_run_at: Time.current)
  end

  def results = last_result.presence || []
  def stale? = last_run_at.nil? || last_run_at < 1.day.ago

  private
    def has_tool_calls
      errors.add(:base, "There's nothing to save: this answer didn't use any data") if tool_calls.blank?
    end
end
