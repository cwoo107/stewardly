# Hourly: at 5am church time, build each staff member's brief; at 6am, email it to those
# who opted in. With a user, rebuilds just theirs ("Refresh").
class DailyBriefJob < ApplicationJob
  BUILD_HOUR = 5
  EMAIL_HOUR = 6

  queue_as :low

  def perform(user = nil)
    return Insights::Brief.new(user).build! if user

    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      hour = church.now.hour
      next unless hour.in?([ BUILD_HOUR, EMAIL_HOUR ])

      ActsAsTenant.with_tenant(church) do
        User.includes(:roles, :ministry_leaderships).find_each do |user|
          next unless user.can?(:view_insights)

          hour == BUILD_HOUR ? Insights::Brief.new(user).build! : email(user, church)
        end
      end
    end
  end

  private
    def email(user, church)
      return unless user.brief_email?

      brief = DailyBrief.find_by(user:, date: church.today)
      return if brief.nil? || brief.emailed_at || brief.insights.empty?

      BriefMailer.with(brief:).daily.deliver_later
      brief.update!(emailed_at: Time.current)
    end
end
