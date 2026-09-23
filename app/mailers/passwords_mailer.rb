class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @church = user.church
    mail subject: "Reset your #{@church.name} password", to: user.email_address
  end
end
