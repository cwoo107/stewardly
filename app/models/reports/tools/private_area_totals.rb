# Prayer and benevolence, as totals only, and only when a church admin has allowed
# private-area totals for AI and reports. Never any request text.
class Reports::Tools::PrivateAreaTotals < Reports::Tool
  self.tool_name = "private_area_totals"
  self.title = "Prayer and benevolence totals"
  self.description = "Counts only: prayer requests received and answered, and benevolence requests, approvals, and dollars paid, in a date range."
  self.permission = "view_benevolence"
  self.parameters = {
    from: { type: "string", format: "date", description: "Start date (YYYY-MM-DD). Default: 12 months ago.", label: "From", default: -> { @today - 365 } },
    to: { type: "string", format: "date", description: "End date (YYYY-MM-DD). Default: today.", label: "To", default: -> { @today } }
  }

  def self.available_to?(user, church)
    church.ai_private_totals? && (user.can?(:view_benevolence) || user.can?(:manage_prayer_requests))
  end

  private
    def call(args)
      range = args["from"].in_time_zone(@church.zone).beginning_of_day..args["to"].in_time_zone(@church.zone).end_of_day
      figures = {}
      if @user.can?(:manage_prayer_requests)
        figures["Prayer requests received"] = PrayerRequest.where(created_at: range).count
        figures["Prayer requests answered"] = PrayerRequest.where(created_at: range, status: "answered").count
      end
      if @user.can?(:view_benevolence)
        cases = BenevolenceCase.where(created_at: range)
        figures["Benevolence requests"] = cases.count
        figures["Benevolence requests approved or fulfilled"] = cases.where(status: %w[ approved fulfilled ]).count
        figures["Benevolence paid (dollars)"] = (BenevolenceDisbursement.where(paid_on: args["from"]..args["to"]).sum(:amount_cents) / 100.0).round(2)
      end
      Result.build(figures:)
    end
end
