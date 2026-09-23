# A month grid (weeks starting Sunday) with calendar items by date.
class Calendar::Month
  attr_reader :month

  def initialize(month:, feed_items_by_date:)
    @month = month.beginning_of_month
    @items = feed_items_by_date
  end

  def self.range_for(month)
    month = month.beginning_of_month
    month.beginning_of_week(:sunday)..month.end_of_month.end_of_week(:sunday)
  end

  def weeks = self.class.range_for(month).each_slice(7).to_a
  def items_on(date) = @items.fetch(date, [])
  def in_month?(date) = date.month == month.month
  def previous = month.prev_month
  def following = month.next_month
end
