# Published forms on the church's subdomain. Public forms are open to anyone;
# members-only forms need a sign-in. Abuse protection: PublicSubmissionProtection,
# plus full server-side validation (Form::Response).
class PublicFormsController < ApplicationController
  include PublicSubmissionProtection

  allow_unauthenticated_access
  before_action :resume_session # a signed-in submitter is linked to their own person
  before_action :set_form
  before_action :require_member_sign_in, if: -> { @form.access_members? }

  protect_submissions only: :create, with: -> { too_many_requests }

  layout "public"

  def show
    render :show, status: :gone if @form.closed?
  end

  def create
    return render(:show, status: :gone) if @form.closed?
    return redirect_to(public_form_thanks_path(@form.slug)) if suspected_bot?

    @response = Form::Response.new(@form, params.fetch(:answers, {}))
    if @response.valid?
      FormSubmission.build_from(@form, @response, user: Current.user, ip_address: request.remote_ip).save!
      redirect_to public_form_thanks_path(@form.slug)
    else
      render :show, status: :unprocessable_content
    end
  end

  def thanks
  end

  private
    def set_form
      @form = Form.includes(:fields).where.not(status: "draft").where.not(purpose: "event_registration").find_by!(slug: params.expect(:slug))
      authorize @form, :show?, policy_class: PublicFormPolicy
    end

    def require_member_sign_in
      request_authentication unless Current.user
    end

    def too_many_requests
      flash.now[:alert] = "That's a lot of submissions. Please wait a minute and try again."
      render :show, status: :too_many_requests
    end
end
