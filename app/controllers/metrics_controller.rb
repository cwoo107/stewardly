# Run any report tool yourself, no AI needed.
class MetricsController < ApplicationController
  def index
    authorize :report, :index?
    skip_policy_scope # tools, not records: each checks its own permission
    @tools = Reports::Tools.available(Current.user, Current.church)
  end

  def show
    authorize :report, :index?
    @tool = Reports::Tools.find(params[:name], user: Current.user, church: Current.church) or raise ActiveRecord::RecordNotFound
    @arguments = params.fetch(:arguments, {}).permit(*@tool.parameters.keys).to_h
    @call = Reports::Execution.run(@tool.tool_name, @arguments, user: Current.user, church: Current.church)
  end
end
