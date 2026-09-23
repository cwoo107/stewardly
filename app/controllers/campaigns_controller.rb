class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[ show edit update destroy schedule deliver cancel ]

  def index
    authorize Campaign
    @pagy, @campaigns = pagy(policy_scope(Campaign).includes(:segment, :email_template).recent_first)
  end

  def show
    return render(:review) if @campaign.editable?

    @stats = @campaign.stats
    @pagy, @deliveries = pagy(@campaign.deliveries.includes(:person).order(:email))
    @deliveries = @deliveries.where(status: params[:status]) if Delivery.statuses.key?(params[:status])
  end

  def new
    @campaign = authorize Campaign.new(email_topic: EmailTopic.default!, email_template: EmailTemplate.alphabetical.first,
      segment_id: params[:segment_id], track_engagement: true)
  end

  def create
    @campaign = authorize Campaign.new(campaign_params.merge(created_by: Current.user))
    @campaign.subject = @campaign.email_template&.subject if @campaign.subject.blank?
    if @campaign.save
      redirect_to @campaign, notice: "Campaign saved as a draft."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: "Campaign saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @campaign.destroy!
    redirect_to campaigns_path, notice: "Campaign deleted.", status: :see_other
  end

  def schedule
    at = Time.zone.parse(params.expect(:scheduled_at).to_s)
    return redirect_to(@campaign, alert: "Choose a time in the future.") unless at&.future?

    @campaign.schedule!(at)
    redirect_to @campaign, notice: "Scheduled for #{l(at, format: :long)}."
  rescue ArgumentError => error
    redirect_to @campaign, alert: error.message
  end

  def deliver
    @campaign.send_now!
    redirect_to @campaign, notice: "Sending now. This page updates as emails go out."
  rescue ArgumentError => error
    redirect_to @campaign, alert: error.message
  end

  def cancel
    @campaign.cancel!
    redirect_to @campaign, notice: "Campaign cancelled.", status: :see_other
  end

  private
    def set_campaign
      @campaign = authorize Campaign.find(params.expect(:id))
    end

    def campaign_params
      params.expect(campaign: %i[ name subject preheader from_name reply_to email_template_id segment_id email_topic_id track_engagement ])
    end
end
