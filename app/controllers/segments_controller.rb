class SegmentsController < ApplicationController
  before_action :set_segment, only: %i[ show edit update destroy ]

  def index
    authorize Segment
    @segments = policy_scope(Segment).alphabetical
  end

  def show
    @pagy, @people = pagy(@segment.people.alphabetical.includes(:tags))
  end

  def new
    # Links can pre-fill conditions (?conditions[][type]=stuck&…); Segment::Condition keeps only known attributes.
    conditions = Array(params[:conditions]).map { |condition| condition.respond_to?(:to_unsafe_h) ? condition.to_unsafe_h : condition }
    @segment = authorize Segment.new(definition: { match: "all", conditions: })
  end

  def create
    @segment = authorize Segment.new(segment_params.merge(created_by: Current.user))
    if @segment.save
      redirect_to @segment, notice: "Segment saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @segment.update(segment_params)
      redirect_to @segment, notice: "Segment saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @segment.destroy!
    redirect_to segments_path, notice: "Segment deleted.", status: :see_other
  end

  # Live count while building (loaded into a Turbo Frame).
  def preview
    authorize Segment, :preview?
    @segment = Segment.new(definition: params.dig(:segment, :definition)&.to_unsafe_h || {})
    @people = @segment.people
    render layout: false
  end

  # One new condition row for the builder, as a Turbo Stream.
  def condition
    authorize Segment, :preview?
    @condition = Segment::Condition.new(type: params[:type])
    @index = params[:index].to_i
    @prefix = params[:prefix].presence_in(%w[ segment pathway_stage workflow_entry workflow_condition ]) || "segment"
  end

  private
    def set_segment
      @segment = authorize policy_scope(Segment).find(params.expect(:id))
    end

    def segment_params
      params.expect(segment: [ :name, :description ]).merge(definition: params.dig(:segment, :definition)&.to_unsafe_h || {})
    end
end
