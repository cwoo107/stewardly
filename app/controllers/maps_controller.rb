class MapsController < ApplicationController
  def show
    authorize :map
    @segments = policy_scope(Segment).alphabetical
    @segment = @segments.find_by(id: params[:segment_id]) if params[:segment_id].present?
    @layers = Map::Layers.new(user: Current.user, segment: @segment, group_type: params[:group_type],
      coverage_gap: params[:coverage_gap] == "1").to_h
  end
end
