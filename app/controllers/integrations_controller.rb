# Connecting a provider. Credentials are write-only: the form never shows saved values,
# and a blank field keeps what's stored.
class IntegrationsController < ApplicationController
  def create
    integration = authorize Integration.new(category: params.dig(:integration, :category), provider: params.dig(:integration, :provider))
    save(integration)
  end

  def update
    integration = authorize Integration.find(params.expect(:id))
    save(integration)
  end

  def destroy
    integration = authorize Integration.find(params.expect(:id))
    integration.destroy!
    redirect_to settings_path_for(integration), notice: "#{integration.label} disconnected.", status: :see_other
  end

  def sync
    integration = authorize Integration.find(params.expect(:id))
    segment = Segment.find(params.expect(:segment_id))
    AudienceSyncJob.perform_later(segment)
    redirect_to email_settings_path, notice: "Sending #{segment.name} to #{integration.label}."
  end

  private
    def settings_path_for(integration) = integration.category == "giving" ? giving_settings_path : email_settings_path

    def save(integration)
      fields = Integration::FIELDS.fetch(integration.provider.to_s, { credentials: [], settings: [] })
      submitted = params.fetch(:integration, {})
      credentials = fields[:credentials].to_h { |key| [ key, submitted.dig(:credentials, key).presence ] }.compact
      settings = fields[:settings].to_h { |key| [ key, submitted.dig(:settings, key).to_s.strip ] }

      integration.credentials = integration.credentials.to_h.merge(credentials)
      integration.settings = integration.settings.to_h.merge(settings)
      if integration.save
        redirect_to settings_path_for(integration), notice: "#{integration.label} connected."
      else
        redirect_to settings_path_for(integration), alert: integration.errors.full_messages.to_sentence
      end
    end
end
