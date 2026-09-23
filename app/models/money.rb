# Integer cents plus an ISO currency, formatted for people. Not a full money library:
# the app never converts currencies or adds amounts across them.
Money = Data.define(:cents, :currency)

class Money
  SYMBOLS = { "USD" => "$", "CAD" => "$", "AUD" => "$", "GBP" => "£", "EUR" => "€" }.freeze

  # "1,250.50" or "$12" → cents; nil when it isn't a number.
  def self.parse_cents(value)
    return if value.blank?

    (BigDecimal(value.to_s.delete(",$ ")) * 100).round.to_i
  rescue ArgumentError
    nil
  end

  def self.format(cents, currency = "USD") = new(cents.to_i, currency).to_s

  def to_s
    amount = ActiveSupport::NumberHelper.number_to_currency(cents / 100.0, unit: SYMBOLS.fetch(currency, ""))
    SYMBOLS.key?(currency) ? amount : "#{amount} #{currency}"
  end
end
