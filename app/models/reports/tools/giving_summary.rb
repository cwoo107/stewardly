class Reports::Tools::GivingSummary < Reports::Tool
  self.tool_name = "giving_summary"
  self.title = "Giving"
  self.description = "Total given in a calendar year (refunds excluded), number of gifts and givers, first-time givers, and totals by fund and by month. Amounts are in dollars."
  self.permission = "view_giving"
  self.parameters = { year: { type: "integer", description: "Calendar year. Default: this year.", label: "Year", default: -> { @today.year } } }

  private
    def call(args)
      summary = Giving::Summary.new(year: args["year"])
      dollars = ->(cents) { (cents / 100.0).round(2) }
      Result.build(figures: { "Given (dollars)" => dollars.(summary.total_cents), "Gifts" => summary.gift_count, "Givers" => summary.giver_count,
        "First-time givers" => summary.first_time_giver_count },
        tables: [ table("By fund", [ "Fund", "Given (dollars)" ], summary.by_fund.map { |fund, cents| [ fund, dollars.(cents) ] }),
          table("By month", [ "Month", "Given (dollars)" ], summary.by_month.map { |month, amount| [ month, amount.round(2) ] }) ])
    end
end
