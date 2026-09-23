class BriefMailer < ApplicationMailer
  def daily
    @brief = params[:brief]
    @user = @brief.user
    mail(to: email_address_with_name(@user.email_address, @user.name), subject: "Your day at #{@brief.church.name}: #{I18n.l(@brief.date, format: :long)}")
  end
end
