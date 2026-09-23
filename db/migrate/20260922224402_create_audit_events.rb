class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :church, null: false, foreign_key: true, index: false
      # No foreign keys on actor/auditable: the trail must survive deletion of what it describes
      t.references :actor, index: true
      t.references :auditable, polymorphic: true, null: false, index: true
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address

      t.datetime :created_at, null: false
    end
    add_index :audit_events, [ :church_id, :created_at ]
  end
end
