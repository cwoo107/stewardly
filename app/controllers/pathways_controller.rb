class PathwaysController < ApplicationController
  before_action :set_pathway

  def show
    authorize @pathway
    @funnel = Pathway::Funnel.new(@pathway)
  end

  # Stages and their rules.
  def edit
    authorize @pathway, :update?
  end

  def update
    authorize @pathway
    if @pathway.update(params.expect(pathway: [ :name ]))
      redirect_to edit_pathway_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_pathway
      @pathway = Pathway.current
    end
end
