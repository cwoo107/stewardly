# Fills a team's open slots for a date range with the best candidates, as pending
# assignments. Deterministic, never double-books a day, and sends nothing: leaders
# review the board, then send requests.
class Scheduling::AutoFill
  def initialize(team:, range:, assigned_by:)
    @board = Scheduling::Board.new(team:, range:)
    @assigned_by = assigned_by
  end

  def fill!
    Assignment.transaction do
      @board.occurrences.sum do |occurrence|
        @board.positions.sum do |position|
          open = @board.cell(occurrence, position).open_slots - created_for(occurrence, position)
          next 0 unless open.positive?

          Scheduling::Candidates.new(occurrence:, position:).best(open).each do |candidate|
            occurrence.assignments.create!(position:, person: candidate.person, assigned_by: @assigned_by)
            created[[ occurrence, position ]] += 1
          end.size
        end
      end
    end
  end

  private
    def created = @created ||= Hash.new(0)
    def created_for(occurrence, position) = created[[ occurrence, position ]]
end
