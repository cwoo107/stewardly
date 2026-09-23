class AnnouncementsController < ApplicationController
  before_action :set_announcement, only: %i[ edit update destroy ]

  def index
    authorize Announcement
    @announcements = policy_scope(Announcement).recent_first.includes(author: :person)
  end

  def new
    @announcement = authorize Announcement.new(published_at: Time.current)
  end

  def create
    @announcement = authorize Announcement.new(announcement_params.merge(author: Current.user))
    if @announcement.save
      redirect_to announcements_path, notice: "Update posted."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @announcement.update(announcement_params)
      redirect_to announcements_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @announcement.destroy!
    redirect_to announcements_path, notice: "Deleted.", status: :see_other
  end

  private
    def set_announcement
      @announcement = authorize policy_scope(Announcement).find(params.expect(:id))
    end

    def announcement_params
      params.expect(announcement: %i[ title body published_at expires_on pinned ])
    end
end
