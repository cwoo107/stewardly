# Turns a submitted step form into that step's stored config: only the keys the type
# uses, cast to the right types. Auto-send is kept as it was unless a church admin changes it.
class Workflow::StepParams
  KEYS = {
    "send_email" => %w[ email_template_id email_topic_id subject ],
    "wait" => %w[ mode amount unit date weekday time ],
    "add_tag" => %w[ tag_id ], "remove_tag" => %w[ tag_id ], "add_to_group" => %w[ group_id ],
    "create_task" => %w[ title notes owner_id due_in_days priority ],
    "notify_staff" => %w[ message ],
    "enroll_in_campaign" => %w[ campaign_id ],
    "ai_draft" => %w[ instructions subject email_template_id email_topic_id ]
  }.freeze
  INTEGERS = %w[ email_template_id email_topic_id tag_id group_id owner_id campaign_id amount due_in_days ].freeze

  def initialize(step, params, user:)
    @step = step
    @params = params.fetch(:config, {}).respond_to?(:to_unsafe_h) ? params.fetch(:config, {}).to_unsafe_h : params.fetch(:config, {}).to_h
    @raw = params
    @user = user
  end

  def config
    type = @step["type"]
    return Segment.new(definition: @raw.dig(:workflow_condition, :definition)&.to_unsafe_h || {}).definition if type == "condition"

    config = Array(KEYS[type]).to_h { |key| [ key, cast(key, @params[key]) ] }
    config["user_ids"] = Array(@params["user_ids"]).compact_blank.map(&:to_i) if type == "notify_staff"
    config["auto_send"] = auto_send if type == "ai_draft"
    config.compact
  end

  private
    def cast(key, value)
      value = value.to_s.strip.presence
      return value&.to_i if INTEGERS.include?(key)

      value
    end

    def auto_send
      current = @step.dig("config", "auto_send").present? && @step.dig("config", "auto_send") != false
      return current unless @user&.church_admin?

      @params["auto_send"] == "1"
    end
end
