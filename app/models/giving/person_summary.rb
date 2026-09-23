# One person's giving for their profile.
class Giving::PersonSummary
  def initialize(person)
    @person = person
    @today = person.church.today
  end

  def gifts = Donation.counted.where(person: @person)
  def this_year_cents = gifts.where(given_on: @today.beginning_of_year..).sum(:amount_cents)
  def last_year_cents = gifts.where(given_on: @today.last_year.beginning_of_year..@today.last_year.end_of_year).sum(:amount_cents)
  def last_gift = @last_gift ||= gifts.order(given_on: :desc).first
end
