class EmailTopicsController < ApplicationController
  before_action :set_topic, only: %i[ edit update destroy ]

  def index
    authorize EmailTopic
    EmailTopic.default!
    @topics = policy_scope(EmailTopic).alphabetical
    @subscriber_counts = EmailPreference.where(subscribed: false).group(:email_topic_id).count
  end

  def new
    @topic = authorize EmailTopic.new(default_subscribed: true)
  end

  def create
    @topic = authorize EmailTopic.new(topic_params)
    if @topic.save
      redirect_to email_topics_path, notice: "Topic added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @topic.update(topic_params)
      redirect_to email_topics_path, notice: "Topic saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @topic.destroy
      redirect_to email_topics_path, notice: "Topic deleted.", status: :see_other
    else
      redirect_to email_topics_path, alert: "Campaigns use this topic, so it can't be deleted.", status: :see_other
    end
  end

  private
    def set_topic
      @topic = authorize EmailTopic.find(params.expect(:id))
    end

    def topic_params = params.expect(email_topic: %i[ name description default_subscribed ])
end
