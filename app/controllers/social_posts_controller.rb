class SocialPostsController < ApplicationController
  before_action :set_post, only: %i[ show edit update destroy schedule publish_now cancel polish ]

  def index
    authorize SocialPost
    @tab = params[:tab].presence_in(%w[ drafts scheduled published attention ]) || "drafts"
    scope = policy_scope(SocialPost).includes(targets: :social_account, media_attachments: :blob).recent_first
    scope = case @tab
    when "drafts" then scope.draft
    when "scheduled" then scope.where(status: %w[ scheduled publishing ])
    when "published" then scope.published
    else scope.needs_attention
    end
    @pagy, @posts = pagy(scope)
    @attention = policy_scope(SocialPost).needs_attention.count
  end

  def show
  end

  def new
    event = Event.find_by(id: params[:event_id])
    return redirect_to(Social::EventPromo.new(event).draft!(force: true) || new_social_post_path, notice: "Here's a draft for #{event.title}.") if event && authorize(SocialPost, :create?)

    @post = authorize SocialPost.new
    @post.account_ids = SocialAccount.usable.ids
  end

  def create
    @post = authorize SocialPost.new(post_params.merge(created_by: Current.user))
    if @post.save
      redirect_to edit_social_post_path(@post), notice: "Draft saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @post.assign_attributes(post_params)
    if @post.save
      redirect_to edit_social_post_path(@post), notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @post.destroy!
    redirect_to social_posts_path, notice: "Post deleted.", status: :see_other
  end

  def schedule
    at = Current.church.zone.parse(params.expect(:scheduled_at).to_s)
    raise ArgumentError, "Choose a date and time" unless at

    @post.schedule!(at)
    redirect_to @post, notice: "Scheduled for #{l(at, format: :long)}."
  rescue ArgumentError => error
    redirect_to edit_social_post_path(@post), alert: error.message
  end

  def publish_now
    @post.publish_now!
    redirect_to @post, notice: "Publishing now. This page shows each account's result."
  rescue ArgumentError => error
    redirect_to edit_social_post_path(@post), alert: error.message
  end

  def cancel
    @post.cancel!
    redirect_to @post, notice: "Cancelled. Nothing more will be posted.", status: :see_other
  end

  # "Polish with AI": rewrites the draft's text (never posts it). Logged like every AI call.
  def polish
    text, = Assistant::Client.new(church: Current.church, user: Current.user, purpose: "social_polish").generate(
      system: "You edit short church social media posts. Keep every fact, date, time, and link exactly as given; don't add any. Make it warm and clear. Reply with the post text only.",
      prompt: @post.body, max_tokens: 400)
    @post.update!(body: text.strip.first(2_200))
    redirect_to edit_social_post_path(@post), notice: "Rewritten with AI. Check it before scheduling."
  rescue Assistant::Client::Unavailable => error
    redirect_to edit_social_post_path(@post), alert: error.message
  end

  private
    def set_post
      @post = authorize SocialPost.find(params.expect(:id))
    end

    def post_params
      attributes = params.expect(social_post: [ :body, :link_url, media: [], account_ids: [], captions: {} ])
      captions = attributes.delete(:captions).to_h
      attributes.delete(:media) if Array(attributes[:media]).compact_blank.empty?
      attributes.merge(captions_by_account: captions)
    end
end
