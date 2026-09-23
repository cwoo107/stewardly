class Member::BlockoutsController < Member::BaseController
  def create
    blockout = person.blockouts.new(params.expect(blockout: %i[ starts_on ends_on reason ]))
    if blockout.save
      redirect_to member_assignments_path, notice: "We won't schedule you then.", status: :see_other
    else
      redirect_to member_assignments_path, alert: blockout.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    person.blockouts.find(params.expect(:id)).destroy!
    redirect_to member_assignments_path, notice: "Removed.", status: :see_other
  end
end
