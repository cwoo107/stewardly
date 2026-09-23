class UsersController < ApplicationController
  before_action :set_user, only: %i[ show destroy ]

  def index
    authorize User
    @users = policy_scope(User).includes(:person, :roles).joins(:person).merge(Person.alphabetical)
  end

  def show
    @grantable_roles = Role.ordered.where.not(id: @user.role_ids).select { |role| policy(UserRole.new(user: @user, role:)).create? }
  end

  def destroy
    @user.destroy!
    redirect_to users_path, notice: "#{@user.name} no longer has an account.", status: :see_other
  end

  private
    def set_user
      @user = policy_scope(User).includes(:person, user_roles: :role).find(params.expect(:id))
      authorize @user
    end
end
