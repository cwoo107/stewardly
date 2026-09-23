class Workflow::Steps::Unknown < Workflow::Steps::Base
  self.label = "Unknown step"

  def errors = [ "isn't a step type this app knows" ]
  def perform(_run, _execution) = Outcome.skip("Unknown step type")
end
