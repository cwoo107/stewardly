class DonationsController < ApplicationController
  def index
    authorize Donation
    scope = policy_scope(Donation).includes(:person, :fund).recent_first
    scope = scope.where(fund_id: params[:fund_id]) if params[:fund_id].present?
    scope = scope.where(match_status: params[:match]) if Donation.match_statuses.key?(params[:match])
    scope = scope.where(given_on: params[:from]..) if (from = (Date.iso8601(params[:from].to_s) rescue nil))
    scope = scope.where(given_on: ..params[:to]) if (to = (Date.iso8601(params[:to].to_s) rescue nil))
    scope = scope.where(person_id: Person.search(params[:q]).select(:id)) if params[:q].present?

    respond_to do |format|
      format.html { @pagy, @donations = pagy(scope) }
      format.csv do
        csv = CSV.generate do |rows|
          rows << %w[ date amount currency fund person status method external_id ]
          scope.find_each { |d| rows << [ d.given_on, format("%.2f", d.amount_cents / 100.0), d.currency, d.fund&.name, d.person&.name, d.status, d.method, d.external_id ] }
        end
        send_data csv, filename: "donations-#{Current.church.today}.csv", type: "text/csv"
      end
    end
  end
end
