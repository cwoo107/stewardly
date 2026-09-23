class UserRolesController < ApplicationController
  before_action :set_user

  def create
    @user_role = @user.user_roles.new(role: Role.find(params.expect(user_role: [ :role_id ])[:role_id]))
    authorize @user_role
    @user_role.save!
    redirect_to @user, notice: "Granted #{@user_role.role.name}.", status: :see_other
  end

  def destroy
    @user_role = @user.user_roles.find(params.expect(:id))
    authorize @user_role

    if @user_role.destroy
      redirect_to @user, notice: "Revoked #{@user_role.role.name}.", status: :see_other
    else
      redirect_to @user, alert: @user_role.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_user
      @user = User.find(params.expect(:user_id))
    end
end
