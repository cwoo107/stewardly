# Member area accounts. `new`/`create`: anyone asks for a link by email (self-claim);
# the reply is always the same so nobody can learn who's in the database.
# `edit`/`update`: the link (from self-claim or a staff invitation) sets a password.
# There's no sign-up for people the church doesn't know.
class AccountSetupsController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized # the signed, expiring token is the authorization
  before_action :set_person, only: %i[ edit update ]
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_account_setup_path, alert: "Try again later." }

  layout "auth"

  def new
  end

  def create
    person = Person.unmerged.find_by(email: params[:email].to_s.strip.downcase)
    AccountMailer.setup(person).deliver_later if person && person.user.nil?
    redirect_to new_session_path, notice: "If we know that email, we've sent a link to set up your account."
  end

  def edit
  end

  def update
    user = User.new(person: @person, email_address: @person.email, password: params[:password],
      password_confirmation: params[:password_confirmation], roles: [ Role.find_by!(key: "member") ])
    if user.save
      start_new_session_for(user)
      redirect_to member_root_path, notice: "Welcome! Your account is ready."
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_person
      @person = Person.unmerged.find_by_token_for(:account_setup, params[:token].to_s)
      redirect_to new_account_setup_path, alert: "That link has expired or was already used. Ask for a new one." unless @person
    end
end
