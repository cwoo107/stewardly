# Which figures in an answer don't come from the data? Every number the AI writes must
# appear in a tool result or argument, or in the question (years and list markers are
# allowed). Percentages and rounding are matched loosely (to a whole number or one decimal).
class Reports::NumberCheck
  NUMBER = /(?<![\w.])-?\$?\d{1,3}(?:,\d{3})+(?:\.\d+)?|(?<![\w.])-?\$?\d+(?:\.\d+)?/

  def initialize(answer:, tool_calls:, question: nil)
    @answer = answer.to_s
    @tool_calls = tool_calls
    @question = question.to_s
  end

  # The figures (as written) that couldn't be traced.
  def unverified
    allowed = known_values
    @answer.scan(NUMBER).uniq.reject do |text|
      value = parse(text)
      value.nil? || year?(value, text) || list_marker?(text) || allowed.any? { |known| close?(value, known) }
    end
  end

  private
    def known_values
      values = []
      collect = ->(object) do
        case object
        when Hash then object.each { |key, value| collect.(key); collect.(value) }
        when Array then object.each { |value| collect.(value) }
        when Numeric then values << object.to_f
        when String then object.scan(NUMBER).each { |text| (number = parse(text)) && values << number }
        end
      end
      collect.(@tool_calls)
      collect.(@question)
      values.uniq
    end

    def parse(text) = Float(text.delete("$,"), exception: false)
    def close?(value, known) = (value - known).abs < 0.05 || value == known.round || value == known.round(1) || (value - known.round).abs < 1e-9
    def year?(value, text) = !text.include?(".") && value.between?(1900, 2100)
    def list_marker?(text) = @answer.match?(/(^|\n)\s*#{Regexp.escape(text)}[.)]\s/)
end
