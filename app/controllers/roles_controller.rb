class RolesController < ApplicationController
  def index
    authorize Role
    @roles = policy_scope(Role).ordered.includes(users: :person)
  end

  def show
    @role = policy_scope(Role).includes(users: :person).find(params.expect(:id))
    authorize @role
  end
end
