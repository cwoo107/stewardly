require_relative "church_preview"

class CampaignMailerPreview < ActionMailer::Preview
  include ChurchPreview

  # "Send me a test" from the template editor.
  def test
    within_church { CampaignMailer.with(template: EmailTemplate.alphabetical.first, person: Person.unmerged.where.not(email: nil).first).test.message }
  end
end
