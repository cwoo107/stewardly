class WorkflowMailer < ApplicationMailer
  def staff_notification
    @user = params[:user]
    @run = params[:run]
    @message = params[:message]
    mail(to: email_address_with_name(@user.email_address, @user.name), subject: "#{@run.workflow.name}: #{@run.person.name}")
  end
end
