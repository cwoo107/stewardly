class BenevolenceDisbursementsController < ApplicationController
  def create
    kase = BenevolenceCase.find(params.expect(:benevolence_case_id))
    authorize kase, :disburse?
    attributes = params.expect(benevolence_disbursement: %i[ amount fund_id paid_on method payee_type payee_name reference ])
    disbursement = kase.disbursements.new(attributes.except(:amount).merge(amount_cents: Money.parse_cents(attributes[:amount]),
      recorded_by: Current.user, currency: kase.currency))
    if disbursement.save
      redirect_to benevolence_case_path(kase, anchor: "payments"), notice: "Payment of #{disbursement.amount} recorded."
    else
      redirect_to benevolence_case_path(kase, anchor: "payments"), alert: disbursement.errors.full_messages.to_sentence
    end
  end
end
