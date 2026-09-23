# The giving dashboard's numbers for a calendar year (church time zone). Refunded and
# failed gifts aren't counted.
class Giving::Summary
  def initialize(year:)
    @year = year
    @range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
  end

  attr_reader :year

  def donations = Donation.counted.where(given_on: @range)
  def total_cents = donations.sum(:amount_cents)
  def gift_count = donations.count
  def giver_count = donations.where.not(person_id: nil).distinct.count(:person_id)
  def unmatched_count = Donation.in_review.count

  # Each unknown donor counts once (matching one of their gifts matches the rest).
  def unmatched_donor_count = Donation.in_review.distinct.count(Arel.sql("COALESCE(donor_external_id, 'gift-' || id::text)"))

  def by_month = donations.group_by_month(:given_on, range: @range, format: "%b").sum(:amount_cents).transform_values { |cents| cents / 100.0 }

  def by_fund
    donations.left_joins(:fund).group(Arel.sql("COALESCE(funds.name, 'No fund')")).order(Arel.sql("SUM(donations.amount_cents) DESC")).sum(:amount_cents)
  end

  # People whose first counted gift ever falls in this year.
  def first_time_giver_count
    firsts = Donation.counted.where.not(person_id: nil).group(:person_id).minimum(:given_on)
    firsts.count { |_, date| @range.cover?(date) }
  end

  def currency = donations.pick(:currency) || "USD"
end
