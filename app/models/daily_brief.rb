# One staff member's ranked insights for a day, with a short AI-written brief (or the
# rule-ranked list when AI is off). items: [{ "insight_id" => 1, "reason" => "..." }, ...]
class DailyBrief < ApplicationRecord
  belongs_to :user
  belongs_to :ai_request, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :source, { ai: "ai", rules: "rules" }, validate: true, prefix: true

  validates :date, presence: true, uniqueness: { scope: :user_id }

  # The ranked insights still worth showing (resolved ones drop out during the day).
  def insights
    ids = items.map { |item| item["insight_id"] }
    Insight.live.where(id: ids).index_by(&:id).values_at(*ids).compact
  end

  def reason_for(insight) = items.find { |item| item["insight_id"] == insight.id }&.dig("reason")
end
