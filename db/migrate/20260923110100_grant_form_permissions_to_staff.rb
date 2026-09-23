# Brings existing churches' default Staff role up to the Phase 2 permission set.
class GrantFormPermissionsToStaff < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE roles SET permissions = ARRAY(SELECT DISTINCT unnest(permissions || ARRAY['manage_forms', 'view_form_submissions']::varchar[]) ORDER BY 1)
      WHERE key = 'staff' AND system
    SQL
  end

  def down
    execute "UPDATE roles SET permissions = array_remove(array_remove(permissions, 'manage_forms'), 'view_form_submissions') WHERE key = 'staff' AND system"
  end
end
