class PathwayStagesController < ApplicationController
  before_action :set_pathway
  before_action :set_stage, only: %i[ edit update destroy move ]

  def new
    @stage = authorize @pathway.stages.new
  end

  def create
    @stage = authorize @pathway.stages.new(stage_params)
    if @stage.save
      replace_everyone
      redirect_to edit_pathway_path, notice: "#{@stage.name} added. People are being re-placed."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @stage.update(stage_params)
      replace_everyone
      redirect_to edit_pathway_path, notice: "#{@stage.name} saved. People are being re-placed."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @stage.destroy!
    redirect_to edit_pathway_path, notice: "Stage removed.", status: :see_other
  end

  def move
    @stage.reposition(params.expect(:position))
    replace_everyone
    head :no_content
  end

  # How many people each stage would hold with the rules being edited (nothing is saved).
  def preview
    authorize PathwayStage, :preview?
    stage = @pathway.stages.find_by(id: params[:stage_id])
    definition = params.dig(:pathway_stage, :definition)&.to_unsafe_h || {}
    @counts = Pathway::Placement.new(@pathway).preview(stage ? { stage.id => definition } : {})
    @stage = stage
    render layout: false
  end

  private
    def set_pathway
      @pathway = Pathway.current
    end

    def set_stage
      @stage = authorize @pathway.stages.find(params.expect(:id))
    end

    def stage_params
      params.expect(pathway_stage: %i[ name description stuck_after_days ])
        .merge(definition: params.dig(:pathway_stage, :definition)&.to_unsafe_h || {})
    end

    def replace_everyone
      PathwayReplacementJob.perform_later(@pathway)
    end
end
