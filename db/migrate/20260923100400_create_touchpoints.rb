class CreateTouchpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :touchpoints do |t|
      t.references :church, null: false, foreign_key: true, index: false
      t.references :person, null: false, foreign_key: true, index: false
      t.references :author, foreign_key: { to_table: :users }
      t.references :subject, polymorphic: true
      t.string :kind, null: false
      t.datetime :occurred_at, null: false
      t.string :summary, null: false
      t.text :body # encrypted
      t.boolean :sensitive, null: false, default: false

      t.timestamps
    end
    add_index :touchpoints, [ :person_id, :occurred_at ]
    # "Who hasn't been reached in N days" looks up the latest touchpoint per person
    add_index :touchpoints, [ :church_id, :person_id, :occurred_at ]
  end
end
