module Assistant::Providers
  class Error < StandardError; end

  ToolCall = Data.define(:name, :arguments)
  Reply = Data.define(:text, :input_tokens, :output_tokens, :raw, :tool_calls) do
    def initialize(text:, input_tokens:, output_tokens:, raw:, tool_calls: []) = super
  end
end
