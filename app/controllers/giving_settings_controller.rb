class GivingSettingsController < ApplicationController
  def show
    authorize :giving_settings
    @integration = Integration.find_by(category: "giving")
    @runs = @integration ? GivingSyncRun.where(integration: @integration).recent_first.limit(10) : []
  end

  def sync
    authorize :giving_settings
    integration = Integration.active.find_by!(category: "giving")
    GivingReconcileJob.perform_later(integration)
    redirect_to giving_settings_path, notice: "Syncing with #{integration.label}. Refresh in a minute to see the result."
  end
end
