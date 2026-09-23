class GrantWorkflowPermissionsToStaff < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE roles SET permissions = ARRAY(SELECT DISTINCT unnest(permissions || ARRAY['manage_workflows', 'approve_messages']::varchar[]) ORDER BY 1)
      WHERE key = 'staff' AND system
    SQL
  end

  def down
    execute "UPDATE roles SET permissions = array_remove(array_remove(permissions, 'manage_workflows'), 'approve_messages') WHERE key = 'staff' AND system"
  end
end
