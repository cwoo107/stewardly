class Reports::Tools::CampaignPerformance < Reports::Tool
  self.tool_name = "campaign_performance"
  self.title = "Email campaigns"
  self.description = "Email campaigns sent since a date, with recipients, delivery, open, click, bounce, and unsubscribe rates."
  self.permission = "manage_email"
  self.parameters = { since: { type: "string", format: "date", description: "Sent on or after (YYYY-MM-DD). Default: 90 days ago.", label: "Since", default: -> { @today - 90 } } }

  private
    def call(args)
      rows = Campaign.sent.where(sent_at: args["since"].beginning_of_day..).order(:sent_at).map do |campaign|
        stats = campaign.stats
        [ campaign.name, campaign.sent_at.to_date.iso8601, stats[:sent], percent(stats[:delivered], stats[:sent]), percent(stats[:opened], stats[:sent]),
          percent(stats[:clicked], stats[:sent]), stats[:bounced], stats[:unsubscribed] ]
      end
      Result.build(figures: { "Campaigns sent" => rows.size, "Emails sent" => rows.sum { |r| r[2] } },
        tables: [ table("Campaigns", [ "Campaign", "Sent on", "Sent", "Delivered (%)", "Opened (%)", "Clicked (%)", "Bounced", "Unsubscribed" ], rows) ])
    end
end
