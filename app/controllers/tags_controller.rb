class TagsController < ApplicationController
  before_action :set_tag, only: %i[ edit update destroy ]

  def index
    authorize Tag
    @tags = policy_scope(Tag).alphabetical.left_joins(:taggings).group(:id).select("tags.*, count(taggings.id) AS people_count")
  end

  def new
    @tag = authorize Tag.new
  end

  def create
    @tag = authorize Tag.new(tag_params)
    if @tag.save
      redirect_to tags_path, notice: "Tag added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: "Tag saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tag.destroy!
    redirect_to tags_path, notice: "Tag deleted.", status: :see_other
  end

  private
    def set_tag
      @tag = authorize policy_scope(Tag).find(params.expect(:id))
    end

    def tag_params
      params.expect(tag: %i[ name color ])
    end
end
