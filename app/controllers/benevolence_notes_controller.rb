class BenevolenceNotesController < ApplicationController
  def create
    kase = BenevolenceCase.find(params.expect(:benevolence_case_id))
    authorize kase, :note?
    note = kase.notes.new(body: params.dig(:benevolence_note, :body), author: Current.user)
    if note.save
      redirect_to benevolence_case_path(kase, anchor: "notes"), notice: "Note added."
    else
      redirect_to benevolence_case_path(kase, anchor: "notes"), alert: "Write something first."
    end
  end
end
