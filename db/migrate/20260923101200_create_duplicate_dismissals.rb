# Staff said "not the same person" for this pair, so the duplicate queue stops suggesting it.
class CreateDuplicateDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :duplicate_dismissals do |t|
      t.references :church, null: false, foreign_key: true
      # person_id < other_person_id, so each pair is stored once
      t.references :person, null: false, foreign_key: true, index: false
      t.references :other_person, null: false, foreign_key: { to_table: :people }
      t.references :dismissed_by, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :duplicate_dismissals, [ :person_id, :other_person_id ], unique: true
  end
end
