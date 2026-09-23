class CreatePlatformSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_sessions do |t|
      t.references :platform_admin, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
