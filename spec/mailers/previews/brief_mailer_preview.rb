require_relative "church_preview"

class BriefMailerPreview < ActionMailer::Preview
  include ChurchPreview

  # The latest brief (or a rule-ranked one built now: previews never call the AI).
  def daily
    within_church do
      brief = DailyBrief.order(:date).last || Insights::Brief.new(User.first).tap { |builder| def builder.ai_ranking(*) = nil }.build!
      BriefMailer.with(brief:).daily.message
    end
  end
end
