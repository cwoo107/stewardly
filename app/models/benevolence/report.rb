# Totals for the benevolence report: the last 12 months of payments by month, need, and fund.
class Benevolence::Report
  def initialize(church)
    @church = church
    @range = (church.today - 1.year + 1.day)..church.today
  end

  def payments = BenevolenceDisbursement.where(paid_on: @range)
  def total_cents = payments.sum(:amount_cents)
  def households_helped = payments.joins(:benevolence_case).distinct.count(Arel.sql("COALESCE(benevolence_cases.household_id::text, 'p' || benevolence_cases.person_id)"))

  def by_month = payments.group_by_month(:paid_on, range: @range, format: "%b %Y").sum(:amount_cents).transform_values { |cents| cents / 100.0 }

  def by_need
    payments.joins(:benevolence_case).group("benevolence_cases.need_category").sum(:amount_cents)
      .transform_keys { |key| BenevolenceCase::NEEDS.fetch(key, key) }.sort_by { |_, cents| -cents }
  end

  def by_fund = payments.left_joins(:fund).group(Arel.sql("COALESCE(funds.name, 'No fund')")).sum(:amount_cents).sort_by { |_, cents| -cents }

  def requests_by_status = BenevolenceCase.where(created_at: @range.first.beginning_of_day..).group(:status).count
end
