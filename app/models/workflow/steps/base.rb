# Shared by every step type.
class Workflow::Steps::Base
  Outcome = Workflow::Steps::Outcome

  class_attribute :label, default: "Step"
  class_attribute :default_config, default: {}

  attr_reader :step, :config

  def initialize(step)
    @step = step
    @config = step["config"].to_h
  end

  def id = step["id"]
  def type = step["type"]
  def errors = []
  def summary = label

  # Does the work for run.person. Must be safe to call again for the same execution.
  def perform(run, execution) = raise(NotImplementedError)

  private
    def church = ActsAsTenant.current_tenant

    def liquid(text, person)
      Email::Liquid.render(text.to_s, "person" => Email::Drops::Person.new(person), "church" => Email::Drops::Church.new(church))
    end

    def exists?(model, key) = config[key].present? && model.exists?(config[key])
end
