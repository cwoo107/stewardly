# Finds pairs of people who are probably the same person, in one query:
# the same email, or the same name plus the same phone digits, birthdate, or household.
# Pairs staff have dismissed are left out.
class Person::DuplicateFinder
  Pair = Data.define(:person, :duplicate, :reason)

  def pairs(limit: 50)
    rows = ActiveRecord::Base.connection.select_rows(ActiveRecord::Base.sanitize_sql_array([ <<~SQL, church_id: church.id, limit: ]))
      SELECT a.id, b.id,
        CASE WHEN a.email IS NOT NULL AND a.email = b.email THEN 'same_email' ELSE 'same_name' END
      FROM people a
      JOIN people b ON b.church_id = a.church_id AND b.id > a.id
      WHERE a.church_id = :church_id
        AND a.merged_into_id IS NULL AND b.merged_into_id IS NULL
        AND (
          (a.email IS NOT NULL AND a.email = b.email)
          OR (
            lower(a.first_name) = lower(b.first_name) AND lower(a.last_name) = lower(b.last_name)
            AND (
              (a.phone IS NOT NULL AND regexp_replace(a.phone, '\\D', '', 'g') = regexp_replace(b.phone, '\\D', '', 'g'))
              OR a.birthdate = b.birthdate
              OR a.household_id = b.household_id
            )
          )
        )
        AND NOT EXISTS (
          SELECT 1 FROM duplicate_dismissals d WHERE d.person_id = a.id AND d.other_person_id = b.id
        )
      ORDER BY a.last_name, a.first_name, a.id, b.id
      LIMIT :limit
    SQL

    people = Person.where(id: rows.flat_map { |a, b, _| [ a, b ] }).includes(:household, :user).index_by(&:id)
    rows.map { |a, b, reason| Pair.new(person: people.fetch(a), duplicate: people.fetch(b), reason:) }
  end

  private
    def church = ActsAsTenant.current_tenant
end
