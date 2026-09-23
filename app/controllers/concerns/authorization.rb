module Authorization
  extend ActiveSupport::Concern
  include Pundit::Authorization

  included do
    after_action :verify_authorized
    after_action :verify_policy_scoped, if: -> { action_name == "index" }

    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  end

  private
    def render_forbidden
      respond_to do |format|
        format.html { render "errors/forbidden", status: :forbidden }
        format.any { head :forbidden }
      end
    end
end
