class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :church, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true, index: { unique: true }
      t.citext :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    # An email address may have an account at more than one church
    add_index :users, [ :church_id, :email_address ], unique: true
  end
end
