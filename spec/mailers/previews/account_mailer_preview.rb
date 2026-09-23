require_relative "church_preview"

class AccountMailerPreview < ActionMailer::Preview
  include ChurchPreview

  def setup = within_church { AccountMailer.setup(Person.unmerged.where.not(email: nil).where.missing(:user).first) }
end
