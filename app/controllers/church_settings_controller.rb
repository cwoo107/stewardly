class ChurchSettingsController < ApplicationController
  before_action :set_church

  def edit
  end

  def update
    if @church.update(church_params)
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
      params.expect(church: %i[ name time_zone group_coverage_miles contact_email giving_url reminder_days_before attendance_categories_text ]).then do |attributes|
        text = attributes.delete(:attendance_categories_text)
        text.nil? ? attributes : attributes.merge(attendance_categories: text.split(/[\n,]/))
      end
    end
end
