require_relative "church_preview"

class WorkflowMailerPreview < ActionMailer::Preview
  include ChurchPreview

  def staff_notification
    within_church do
      run = WorkflowRun.first
      WorkflowMailer.with(user: User.first, run:, message: "#{run.person.name} visited for the first time two weeks ago and hasn't been back.").staff_notification.message
    end
  end
end
