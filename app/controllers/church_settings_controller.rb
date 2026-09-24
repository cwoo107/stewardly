class ChurchSettingsController < ApplicationController
  before_action :set_church

  def edit
  end

  def update
    @church.logo.purge_later if params.dig(:church, :remove_logo) == "1" && @church.logo.attached?
    if @church.update(church_params)
      @church.site&.expire_cache! # the website shows the church logo and name
      redirect_to edit_church_settings_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_church
      @church = Current.church
      authorize @church
    end

    def church_params
      params.expect(church: %i[ name time_zone group_coverage_miles contact_email giving_url reminder_days_before attendance_categories_text
      logo ai_enabled ai_monthly_token_cap workflow_daily_send_limit no_contact_days ai_private_totals social_event_promos
      benevolence_approval_threshold benevolence_approvals_required benevolence_annual_limit benevolence_limit_scope ]).then do |attributes|
        %i[ benevolence_approval_threshold benevolence_annual_limit ].each do |key|
          attributes[:"#{key}_cents"] = Money.parse_cents(attributes.delete(key)).to_i if attributes.key?(key)
        end
        text = attributes.delete(:attendance_categories_text)
        text.nil? ? attributes : attributes.merge(attendance_categories: text.split(/[\n,]/))
      end
    end
end
