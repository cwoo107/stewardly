# Staffing needs on a worship service (every week) or an event (each date).
class PositionNeedsController < ApplicationController
  NEEDABLE_TYPES = { "WorshipService" => WorshipService, "Event" => Event }.freeze

  def create
    needable = NEEDABLE_TYPES.fetch(params.expect(position_need: [ :needable_type ])[:needable_type]).find(params.dig(:position_need, :needable_id))
    need = authorize needable.position_needs.new(params.expect(position_need: %i[ position_id quantity ]))
    if need.save
      redirect_back_or_to needable_path(needable), notice: "#{need.position.name} need added.", status: :see_other
    else
      redirect_back_or_to needable_path(needable), alert: need.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def update
    need = authorize PositionNeed.find(params.expect(:id))
    need.update!(params.expect(position_need: [ :quantity ]))
    redirect_back_or_to needable_path(need.needable), notice: "Saved.", status: :see_other
  end

  def destroy
    need = authorize PositionNeed.find(params.expect(:id))
    need.destroy!
    redirect_back_or_to needable_path(need.needable), notice: "Need removed.", status: :see_other
  end

  private
    def needable_path(needable)
      needable.is_a?(Event) ? edit_event_path(needable) : edit_worship_service_path(needable)
    end
end
