# One turn of a report conversation. Assistant turns keep the tool calls behind them:
#   tool_calls: [{ "name" =>, "arguments" => {}, "result" => Reports::Tool::Result#to_h }]
class ReportMessage < ApplicationRecord
  belongs_to :report_conversation
  belongs_to :ai_request, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :role, { user: "user", assistant: "assistant" }, validate: true, prefix: true
  enum :status, { pending: "pending", done: "done", failed: "failed" }, default: :done, validate: true

  def question = report_conversation.messages.where(role: "user").where(id: ...id).last&.content
end
