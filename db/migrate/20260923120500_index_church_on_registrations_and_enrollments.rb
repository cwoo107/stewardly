# Every tenant table needs an index led by church_id (tenant scoping filters on it first).
class IndexChurchOnRegistrationsAndEnrollments < ActiveRecord::Migration[8.1]
  def change
    add_index :registrations, [ :church_id, :person_id ]
    add_index :enrollments, [ :church_id, :person_id ]
  end
end
