require_relative "church_preview"

class GroupJoinRequestMailerPreview < ActionMailer::Preview
  include ChurchPreview

  def received = within_church { GroupJoinRequestMailer.received(GroupJoinRequest.first) }
  def decided = within_church { GroupJoinRequestMailer.decided(GroupJoinRequest.first) }
end
