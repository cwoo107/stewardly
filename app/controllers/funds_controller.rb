class FundsController < ApplicationController
  before_action :set_fund, only: %i[ edit update ]

  def index
    authorize Fund
    @funds = policy_scope(Fund).alphabetical
    @totals = Donation.counted.where(given_on: Current.church.today.beginning_of_year..).group(:fund_id).sum(:amount_cents)
  end

  def new
    @fund = authorize Fund.new(benevolence: params[:benevolence].present?)
  end

  def create
    @fund = authorize Fund.new(fund_params.merge(provider: "manual"))
    @fund.benevolence = true unless policy(Fund).change_benevolence_flag?
    if @fund.save
      redirect_to funds_path, notice: "#{@fund.name} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    # Synced funds are named by the provider; only whether they're used for benevolence can change here.
    attributes = @fund.manual? ? fund_params : fund_params.slice(:benevolence)
    attributes = attributes.except(:benevolence) unless policy(Fund).change_benevolence_flag?
    if @fund.update(attributes)
      redirect_to funds_path, notice: "#{@fund.name} saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_fund
      @fund = authorize policy_scope(Fund).find(params.expect(:id))
    end

    def fund_params = params.expect(fund: %i[ name description active benevolence ])
end
