class AuditEventsController < ApplicationController
  PER_PAGE = 50

  def index
    authorize AuditEvent
    # Plain offset paging until pagy arrives with the people database in Phase 1.
    @page = [ params.fetch(:page, 1).to_i, 1 ].max
    events = policy_scope(AuditEvent).recent_first.includes(actor: :person).offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = events.size > PER_PAGE
    @audit_events = events.first(PER_PAGE)
  end
end
