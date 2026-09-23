class Platform::ChurchesController < Platform::BaseController
  def index
    authorize Church
    @churches = policy_scope(Church).order(:name)
  end

  def new
    authorize Church
    @church = Church.new(time_zone: "Central Time (US & Canada)")
  end

  def create
    authorize Church
    provisioning = Church::Provisioning.new(**church_params, admin: admin_params)
    provisioning.provision!
    redirect_to platform_churches_path, notice: "#{provisioning.church.name} is ready at #{provisioning.church.host}."
  rescue ActiveRecord::RecordInvalid => error
    @church = provisioning.church
    @errors = error.record.errors.full_messages
    render :new, status: :unprocessable_content
  end

  private
    def church_params
      params.expect(church: %i[ name subdomain time_zone ]).to_h.symbolize_keys
    end

    def admin_params
      params.expect(admin: %i[ first_name last_name email_address password ])
    end
end
