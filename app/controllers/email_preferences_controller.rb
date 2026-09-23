# "Email preferences" from every campaign footer: which topics a person gets. The signed
# token (Person#generate_token_for(:email_preferences)) is the key; it stops working if
# their email address changes.
class EmailPreferencesController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized # the signed token is the authorization
  before_action :set_person

  layout "public"

  def show
    @topics = EmailTopic.alphabetical
    @unsubscribed_from_all = Suppression.unsubscribed.exists?(email: @person.email, email_topic_id: nil)
  end

  def update
    chosen = Array(params[:topic_ids]).map(&:to_i)
    EmailPreference.transaction do
      EmailTopic.find_each do |topic|
        @person.email_preferences.find_or_initialize_by(email_topic: topic).update!(subscribed: chosen.include?(topic.id))
      end
      unsubscribes = Suppression.unsubscribed.where(email: @person.email)
      if params[:all] == "none"
        Suppression.record!(@person.email, reason: :unsubscribed, source: "preferences")
      else
        unsubscribes.delete_all # choosing topics again undoes earlier unsubscribes
      end
    end
    redirect_to email_preferences_path(params[:token]), notice: "Your email preferences are saved.", status: :see_other
  end

  private
    def set_person
      @person = Person.find_by_token_for!(:email_preferences, params.expect(:token).to_s)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      render :expired, status: :not_found
    end
end
