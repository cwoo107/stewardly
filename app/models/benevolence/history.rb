# Everything given to a person and their household, for the case page.
class Benevolence::History
  def initialize(kase)
    @case = kase
  end

  def cases
    scope = BenevolenceCase.where(person_id: @case.person_id)
    scope = scope.or(BenevolenceCase.where(household_id: @case.household_id)) if @case.household_id
    scope.where.not(id: @case.id).includes(:person).recent_first
  end

  def paid_cents
    ids = cases.unscope(:order).select(:id)
    BenevolenceDisbursement.where(benevolence_case_id: ids).or(BenevolenceDisbursement.where(benevolence_case_id: @case.id)).sum(:amount_cents)
  end
end
