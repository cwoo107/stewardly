# The sandbox every template and section renders in: strict parsing, strict variables
# and filters, render limits, and only the whitelisted drops passed in (never models).
module Email::Liquid
  LIMITS = { render_length_limit: 500_000, render_score_limit: 100_000, assign_score_limit: 10_000 }.freeze

  module Filters
    # Markdown for text settings; any HTML typed into them is escaped.
    def markdown(input)
      Commonmarker.to_html(input.to_s, options: { render: { unsafe: false, escape: true }, extension: { autolink: true, strikethrough: true } })
    end
  end

  ENVIRONMENT = Liquid::Environment.build(error_mode: :strict) { |environment| environment.register_filter(Filters) }

  def self.parse(source) = Liquid::Template.parse(source.to_s, environment: ENVIRONMENT)

  def self.render(template, assigns)
    template = parse(template) unless template.is_a?(Liquid::Template)
    context = Liquid::Context.build(environment: ENVIRONMENT, environments: [ assigns.deep_stringify_keys ], rethrow_errors: true,
      resource_limits: Liquid::ResourceLimits.new(LIMITS))
    context.strict_variables = true
    context.strict_filters = true
    template.render!(context)
  end
end
