require_relative "church_preview"

class PasswordsMailerPreview < ActionMailer::Preview
  include ChurchPreview

  def reset = within_church { PasswordsMailer.reset(User.first).message }
end
