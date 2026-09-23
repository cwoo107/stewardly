class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :church, null: false, foreign_key: true
      t.references :household, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :nickname
      t.citext :email
      t.string :phone
      t.date :birthdate
      t.string :membership_status, null: false, default: "guest"
      t.string :household_role, null: false, default: "adult"

      t.timestamps
    end
    add_index :people, [ :church_id, :last_name, :first_name ]
    add_index :people, [ :church_id, :email ]
  end
end
