# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_23_130100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "postgis"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.bigint "author_id"
    t.text "body", null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.date "expires_on"
    t.boolean "pinned", default: false, null: false
    t.datetime "published_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_announcements_on_author_id"
    t.index ["church_id", "published_at"], name: "index_announcements_on_church_id_and_published_at"
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "assigned_by_id"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.date "local_date", null: false
    t.text "note"
    t.bigint "person_id", null: false
    t.bigint "position_id", null: false
    t.datetime "reminded_at"
    t.datetime "requested_at"
    t.datetime "responded_at"
    t.string "response_token", null: false
    t.bigint "schedulable_id", null: false
    t.string "schedulable_type", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_id"], name: "index_assignments_on_assigned_by_id"
    t.index ["church_id", "person_id", "local_date"], name: "index_assignments_on_church_id_and_person_id_and_local_date"
    t.index ["person_id"], name: "index_assignments_on_person_id"
    t.index ["position_id"], name: "index_assignments_on_position_id"
    t.index ["response_token"], name: "index_assignments_on_response_token", unique: true
    t.index ["schedulable_type", "schedulable_id", "position_id", "person_id"], name: "index_assignments_uniqueness", unique: true
  end

  create_table "attendance_counts", force: :cascade do |t|
    t.jsonb "breakdown", default: {}, null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.integer "first_time_guests", default: 0, null: false
    t.text "note"
    t.bigint "recorded_by_id"
    t.bigint "service_occurrence_id", null: false
    t.integer "total", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_attendance_counts_on_church_id"
    t.index ["recorded_by_id"], name: "index_attendance_counts_on_recorded_by_id"
    t.index ["service_occurrence_id"], name: "index_attendance_counts_on_service_occurrence_id", unique: true
  end

  create_table "attendance_forecasts", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.integer "expected", null: false
    t.integer "expected_online"
    t.jsonb "factors", default: [], null: false
    t.datetime "frozen_at"
    t.datetime "generated_at", null: false
    t.integer "high", null: false
    t.integer "low", null: false
    t.string "model_version", null: false
    t.bigint "service_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "generated_at"], name: "index_attendance_forecasts_on_church_id_and_generated_at"
    t.index ["service_occurrence_id"], name: "index_attendance_forecasts_on_service_occurrence_id", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.datetime "checked_in_at", null: false
    t.bigint "checked_in_by_id"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.boolean "first_time", default: false, null: false
    t.bigint "person_id", null: false
    t.bigint "service_occurrence_id", null: false
    t.datetime "updated_at", null: false
    t.index ["checked_in_by_id"], name: "index_attendances_on_checked_in_by_id"
    t.index ["church_id", "person_id", "checked_in_at"], name: "index_attendances_on_church_id_and_person_id_and_checked_in_at"
    t.index ["person_id"], name: "index_attendances_on_person_id"
    t.index ["service_occurrence_id", "person_id"], name: "index_attendances_on_service_occurrence_id_and_person_id", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["church_id", "created_at"], name: "index_audit_events_on_church_id_and_created_at"
  end

  create_table "blockouts", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.bigint "person_id", null: false
    t.string "reason"
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "person_id", "starts_on"], name: "index_blockouts_on_church_id_and_person_id_and_starts_on"
  end

  create_table "campuses", force: :cascade do |t|
    t.string "address_line1"
    t.string "address_line2"
    t.bigint "church_id", null: false
    t.string "city"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.string "geocode_error"
    t.datetime "geocoded_at"
    t.boolean "is_default", default: false, null: false
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}
    t.string "name", null: false
    t.string "postal_code"
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_campuses_on_church_id"
    t.index ["church_id"], name: "index_campuses_one_default_per_church", unique: true, where: "is_default"
    t.index ["location"], name: "index_campuses_on_location", using: :gist
  end

  create_table "churches", force: :cascade do |t|
    t.string "attendance_categories", default: ["Adults", "Kids", "Online"], null: false, array: true
    t.string "contact_email"
    t.datetime "created_at", null: false
    t.string "giving_url"
    t.integer "group_coverage_miles", default: 3, null: false
    t.string "name", null: false
    t.integer "reminder_days_before", default: 3, null: false
    t.citext "subdomain", null: false
    t.string "time_zone", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_churches_on_subdomain", unique: true
  end

  create_table "course_offerings", force: :cascade do |t|
    t.integer "capacity"
    t.bigint "church_id", null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.boolean "enrollment_open", default: true, null: false
    t.bigint "leader_id"
    t.string "location_name"
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_course_offerings_on_church_id"
    t.index ["course_id"], name: "index_course_offerings_on_course_id"
    t.index ["leader_id"], name: "index_course_offerings_on_leader_id"
  end

  create_table "course_sessions", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.bigint "course_offering_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.date "local_date", null: false
    t.datetime "starts_at", null: false
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["church_id", "local_date"], name: "index_course_sessions_on_church_id_and_local_date"
    t.index ["course_offering_id", "starts_at"], name: "index_course_sessions_on_course_offering_id_and_starts_at"
  end

  create_table "courses", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "ministry_id"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_courses_on_church_id"
    t.index ["ministry_id"], name: "index_courses_on_ministry_id"
  end

  create_table "custom_fields", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "options", default: [], null: false, array: true
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "key"], name: "index_custom_fields_on_church_id_and_key", unique: true
    t.index ["church_id", "position"], name: "index_custom_fields_on_church_id_and_position"
  end

  create_table "duplicate_dismissals", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "dismissed_by_id"
    t.bigint "other_person_id", null: false
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_duplicate_dismissals_on_church_id"
    t.index ["dismissed_by_id"], name: "index_duplicate_dismissals_on_dismissed_by_id"
    t.index ["other_person_id"], name: "index_duplicate_dismissals_on_other_person_id"
    t.index ["person_id", "other_person_id"], name: "index_duplicate_dismissals_on_person_id_and_other_person_id", unique: true
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "completed_at"
    t.bigint "course_offering_id", null: false
    t.datetime "created_at", null: false
    t.bigint "person_id", null: false
    t.datetime "promoted_at"
    t.string "status", default: "enrolled", null: false
    t.datetime "updated_at", null: false
    t.datetime "withdrawn_at"
    t.index ["church_id", "person_id"], name: "index_enrollments_on_church_id_and_person_id"
    t.index ["course_offering_id", "person_id"], name: "index_enrollments_on_course_offering_id_and_person_id", unique: true
    t.index ["course_offering_id", "status", "created_at"], name: "idx_on_course_offering_id_status_created_at_4ac5589ad5"
    t.index ["person_id"], name: "index_enrollments_on_person_id"
  end

  create_table "event_occurrences", force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.integer "capacity"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.bigint "event_id", null: false
    t.date "local_date", null: false
    t.datetime "reminders_sent_at"
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "local_date"], name: "index_event_occurrences_on_church_id_and_local_date"
    t.index ["event_id"], name: "index_event_occurrences_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "address_line1"
    t.bigint "campus_id"
    t.integer "capacity"
    t.bigint "church_id", null: false
    t.string "city"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "location_name"
    t.integer "max_party_size", default: 1, null: false
    t.bigint "ministry_id"
    t.bigint "organizer_id"
    t.string "postal_code"
    t.string "region"
    t.datetime "registration_closes_at"
    t.bigint "registration_form_id"
    t.datetime "registration_opens_at"
    t.boolean "registration_required", default: false, null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "public", null: false
    t.index ["campus_id"], name: "index_events_on_campus_id"
    t.index ["church_id", "slug"], name: "index_events_on_church_id_and_slug", unique: true
    t.index ["ministry_id"], name: "index_events_on_ministry_id"
    t.index ["organizer_id"], name: "index_events_on_organizer_id"
    t.index ["registration_form_id"], name: "index_events_on_registration_form_id"
  end

  create_table "form_fields", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.bigint "form_id", null: false
    t.text "help_text"
    t.string "key", null: false
    t.string "label", null: false
    t.string "maps_to"
    t.string "options", default: [], null: false, array: true
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.boolean "sensitive", default: false, null: false
    t.datetime "updated_at", null: false
    t.jsonb "visibility_rule", default: {}, null: false
    t.index ["church_id"], name: "index_form_fields_on_church_id"
    t.index ["form_id", "key"], name: "index_form_fields_on_form_id_and_key", unique: true
    t.index ["form_id", "maps_to"], name: "index_form_fields_on_form_id_and_maps_to", unique: true, where: "(maps_to IS NOT NULL)"
    t.index ["form_id", "position"], name: "index_form_fields_on_form_id_and_position"
  end

  create_table "form_submissions", force: :cascade do |t|
    t.jsonb "answers", default: {}, null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "form_id", null: false
    t.string "ip_address"
    t.bigint "person_id"
    t.datetime "processed_at"
    t.text "sensitive_answers"
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["church_id", "status"], name: "index_form_submissions_on_church_id_and_status"
    t.index ["form_id", "created_at"], name: "index_form_submissions_on_form_id_and_created_at"
    t.index ["person_id"], name: "index_form_submissions_on_person_id"
    t.index ["user_id"], name: "index_form_submissions_on_user_id"
  end

  create_table "forms", force: :cascade do |t|
    t.string "access", default: "public", null: false
    t.bigint "church_id", null: false
    t.text "confirmation_message"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "published_at"
    t.string "purpose", default: "general", null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "slug"], name: "index_forms_on_church_id_and_slug", unique: true
  end

  create_table "group_join_requests", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.bigint "decided_by_id"
    t.bigint "group_id", null: false
    t.text "message"
    t.bigint "person_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "status"], name: "index_group_join_requests_on_church_id_and_status"
    t.index ["decided_by_id"], name: "index_group_join_requests_on_decided_by_id"
    t.index ["group_id", "person_id"], name: "index_group_join_requests_one_pending", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["group_id", "status"], name: "index_group_join_requests_on_group_id_and_status"
    t.index ["person_id"], name: "index_group_join_requests_on_person_id"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.date "joined_on", null: false
    t.bigint "person_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_group_memberships_on_church_id"
    t.index ["group_id", "person_id"], name: "index_group_memberships_on_group_id_and_person_id", unique: true
    t.index ["person_id"], name: "index_group_memberships_on_person_id"
  end

  create_table "groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address_line1"
    t.string "address_line2"
    t.integer "capacity"
    t.bigint "church_id", null: false
    t.string "city"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "geocode_error"
    t.datetime "geocoded_at"
    t.string "group_type", default: "small_group", null: false
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}
    t.integer "meeting_day"
    t.string "meeting_frequency", default: "weekly", null: false
    t.time "meeting_time"
    t.bigint "ministry_id"
    t.string "name", null: false
    t.string "postal_code"
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["church_id", "group_type"], name: "index_groups_on_church_id_and_group_type"
    t.index ["church_id"], name: "index_groups_on_church_id"
    t.index ["location"], name: "index_groups_on_location", using: :gist
    t.index ["ministry_id"], name: "index_groups_on_ministry_id"
  end

  create_table "households", force: :cascade do |t|
    t.string "address_line1"
    t.string "address_line2"
    t.bigint "church_id", null: false
    t.string "city"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.string "geocode_error"
    t.datetime "geocoded_at"
    t.geography "location", limit: {srid: 4326, type: "st_point", geographic: true}
    t.string "name", null: false
    t.string "postal_code"
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_households_on_church_id"
    t.index ["location"], name: "index_households_on_location", using: :gist
  end

  create_table "ministries", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "name"], name: "index_ministries_on_church_id_and_name", unique: true
  end

  create_table "ministry_leaderships", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "ministry_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["church_id"], name: "index_ministry_leaderships_on_church_id"
    t.index ["ministry_id", "user_id"], name: "index_ministry_leaderships_on_ministry_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_ministry_leaderships_on_user_id"
  end

  create_table "people", force: :cascade do |t|
    t.date "birthdate"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.citext "email"
    t.string "first_name", null: false
    t.bigint "household_id"
    t.string "household_role", default: "adult", null: false
    t.string "last_name", null: false
    t.string "membership_status", default: "guest", null: false
    t.datetime "merged_at"
    t.bigint "merged_into_id"
    t.string "nickname"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index "((((first_name)::text || ' '::text) || (last_name)::text)) gin_trgm_ops", name: "index_people_on_full_name_trgm", using: :gin
    t.index ["church_id", "email"], name: "index_people_on_church_id_and_email"
    t.index ["church_id", "last_name", "first_name"], name: "index_people_on_church_id_and_last_name_and_first_name"
    t.index ["church_id"], name: "index_people_on_church_id"
    t.index ["custom_fields"], name: "index_people_on_custom_fields", using: :gin
    t.index ["email"], name: "index_people_on_email_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["household_id"], name: "index_people_on_household_id"
    t.index ["merged_into_id"], name: "index_people_on_merged_into_id"
    t.index ["phone"], name: "index_people_on_phone_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "person_imports", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.integer "created_count", default: 0, null: false
    t.datetime "finished_at"
    t.jsonb "mapping", default: {}, null: false
    t.integer "processed_count", default: 0, null: false
    t.integer "row_count", default: 0, null: false
    t.jsonb "row_errors", default: [], null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.index ["church_id"], name: "index_person_imports_on_church_id"
    t.index ["created_by_id"], name: "index_person_imports_on_created_by_id"
  end

  create_table "platform_admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_platform_admins_on_email_address", unique: true
  end

  create_table "platform_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.bigint "platform_admin_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["platform_admin_id"], name: "index_platform_sessions_on_platform_admin_id"
  end

  create_table "position_needs", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "needable_id", null: false
    t.string "needable_type", null: false
    t.bigint "position_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_position_needs_on_church_id"
    t.index ["needable_type", "needable_id", "position_id"], name: "index_position_needs_uniqueness", unique: true
    t.index ["position_id"], name: "index_position_needs_on_position_id"
  end

  create_table "position_qualifications", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "person_id", null: false
    t.bigint "position_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_position_qualifications_on_church_id"
    t.index ["person_id"], name: "index_position_qualifications_on_person_id"
    t.index ["position_id", "person_id"], name: "index_position_qualifications_on_position_id_and_person_id", unique: true
  end

  create_table "positions", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_positions_on_church_id"
    t.index ["team_id"], name: "index_positions_on_team_id"
  end

  create_table "prayer_assignments", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "prayer_request_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["church_id"], name: "index_prayer_assignments_on_church_id"
    t.index ["prayer_request_id", "user_id"], name: "index_prayer_assignments_on_prayer_request_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_prayer_assignments_on_user_id"
  end

  create_table "prayer_requests", force: :cascade do |t|
    t.text "answer_note"
    t.datetime "answered_at"
    t.text "body", null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "form_submission_id"
    t.bigint "person_id"
    t.string "requester_email"
    t.string "requester_name"
    t.string "source", default: "staff", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "pastoral_staff", null: false
    t.index ["church_id", "status", "created_at"], name: "index_prayer_requests_on_church_id_and_status_and_created_at"
    t.index ["created_by_id"], name: "index_prayer_requests_on_created_by_id"
    t.index ["form_submission_id"], name: "index_prayer_requests_on_form_submission_id"
    t.index ["person_id"], name: "index_prayer_requests_on_person_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_projects_on_church_id"
  end

  create_table "registrations", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "checked_in_at"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "event_occurrence_id", null: false
    t.bigint "form_submission_id"
    t.string "manage_token", null: false
    t.integer "party_size", default: 1, null: false
    t.bigint "person_id", null: false
    t.datetime "promoted_at"
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "person_id"], name: "index_registrations_on_church_id_and_person_id"
    t.index ["event_occurrence_id", "person_id"], name: "index_registrations_one_active_per_person", unique: true, where: "((status)::text <> 'cancelled'::text)"
    t.index ["event_occurrence_id", "status", "created_at"], name: "idx_on_event_occurrence_id_status_created_at_96b43c84ff"
    t.index ["form_submission_id"], name: "index_registrations_on_form_submission_id"
    t.index ["manage_token"], name: "index_registrations_on_manage_token", unique: true
    t.index ["person_id"], name: "index_registrations_on_person_id"
  end

  create_table "roles", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.boolean "grants_all", default: false, null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "permissions", default: [], null: false, array: true
    t.boolean "system", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "key"], name: "index_roles_on_church_id_and_key", unique: true
    t.index ["church_id"], name: "index_roles_on_church_id"
  end

  create_table "segments", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.jsonb "definition", default: {}, null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "name"], name: "index_segments_on_church_id_and_name", unique: true
    t.index ["created_by_id"], name: "index_segments_on_created_by_id"
  end

  create_table "service_occurrences", force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.date "local_date", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "worship_service_id", null: false
    t.index ["church_id", "local_date"], name: "index_service_occurrences_on_church_id_and_local_date"
    t.index ["worship_service_id", "local_date"], name: "index_service_occurrences_on_worship_service_id_and_local_date", unique: true
  end

  create_table "session_attendances", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.bigint "course_session_id", null: false
    t.datetime "created_at", null: false
    t.bigint "enrollment_id", null: false
    t.boolean "present", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_session_attendances_on_church_id"
    t.index ["course_session_id", "enrollment_id"], name: "idx_on_course_session_id_enrollment_id_94db20281a", unique: true
    t.index ["enrollment_id"], name: "index_session_attendances_on_enrollment_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["church_id"], name: "index_sessions_on_church_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "special_sundays", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.integer "expected_change_percent"
    t.string "key", null: false
    t.date "local_date", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "key"], name: "index_special_sundays_on_church_id_and_key"
    t.index ["church_id", "local_date"], name: "index_special_sundays_on_church_id_and_local_date", unique: true
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "person_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_taggings_on_church_id"
    t.index ["person_id", "tag_id"], name: "index_taggings_on_person_id_and_tag_id", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.string "color", default: "gray", null: false
    t.datetime "created_at", null: false
    t.citext "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "name"], name: "index_tags_on_church_id_and_name", unique: true
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.date "due_on"
    t.text "notes"
    t.bigint "owner_id"
    t.integer "position", default: 0, null: false
    t.string "priority", default: "normal", null: false
    t.bigint "project_id"
    t.string "status", default: "todo", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "due_on"], name: "index_tasks_on_church_id_and_due_on"
    t.index ["church_id", "status", "position"], name: "index_tasks_on_church_id_and_status_and_position"
    t.index ["created_by_id"], name: "index_tasks_on_created_by_id"
    t.index ["owner_id"], name: "index_tasks_on_owner_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.integer "max_per_month"
    t.bigint "person_id", null: false
    t.string "role", default: "member", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_team_memberships_on_church_id"
    t.index ["person_id"], name: "index_team_memberships_on_person_id"
    t.index ["team_id", "person_id"], name: "index_team_memberships_on_team_id_and_person_id", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "ministry_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id"], name: "index_teams_on_church_id"
    t.index ["ministry_id"], name: "index_teams_on_ministry_id"
  end

  create_table "touchpoints", force: :cascade do |t|
    t.bigint "author_id"
    t.text "body"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.datetime "occurred_at", null: false
    t.bigint "person_id", null: false
    t.boolean "sensitive", default: false, null: false
    t.bigint "subject_id"
    t.string "subject_type"
    t.string "summary", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_touchpoints_on_author_id"
    t.index ["church_id", "person_id", "occurred_at"], name: "index_touchpoints_on_church_id_and_person_id_and_occurred_at"
    t.index ["person_id", "occurred_at"], name: "index_touchpoints_on_person_id_and_occurred_at"
    t.index ["subject_type", "subject_id"], name: "index_touchpoints_on_subject"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["church_id"], name: "index_user_roles_on_church_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.citext "email_address", null: false
    t.string "password_digest", null: false
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["church_id", "email_address"], name: "index_users_on_church_id_and_email_address", unique: true
    t.index ["church_id"], name: "index_users_on_church_id"
    t.index ["person_id"], name: "index_users_on_person_id", unique: true
  end

  create_table "worship_services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "campus_id"
    t.bigint "church_id", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week", default: 0, null: false
    t.integer "duration_minutes", default: 75, null: false
    t.string "name", null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id"], name: "index_worship_services_on_campus_id"
    t.index ["church_id"], name: "index_worship_services_on_church_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "announcements", "churches"
  add_foreign_key "announcements", "users", column: "author_id"
  add_foreign_key "assignments", "churches"
  add_foreign_key "assignments", "people"
  add_foreign_key "assignments", "positions"
  add_foreign_key "assignments", "users", column: "assigned_by_id"
  add_foreign_key "attendance_counts", "churches"
  add_foreign_key "attendance_counts", "service_occurrences"
  add_foreign_key "attendance_counts", "users", column: "recorded_by_id"
  add_foreign_key "attendance_forecasts", "churches"
  add_foreign_key "attendance_forecasts", "service_occurrences"
  add_foreign_key "attendances", "churches"
  add_foreign_key "attendances", "people"
  add_foreign_key "attendances", "service_occurrences"
  add_foreign_key "attendances", "users", column: "checked_in_by_id"
  add_foreign_key "audit_events", "churches"
  add_foreign_key "blockouts", "churches"
  add_foreign_key "blockouts", "people"
  add_foreign_key "campuses", "churches"
  add_foreign_key "course_offerings", "churches"
  add_foreign_key "course_offerings", "courses"
  add_foreign_key "course_offerings", "people", column: "leader_id"
  add_foreign_key "course_sessions", "churches"
  add_foreign_key "course_sessions", "course_offerings"
  add_foreign_key "courses", "churches"
  add_foreign_key "courses", "ministries"
  add_foreign_key "custom_fields", "churches"
  add_foreign_key "duplicate_dismissals", "churches"
  add_foreign_key "duplicate_dismissals", "people"
  add_foreign_key "duplicate_dismissals", "people", column: "other_person_id"
  add_foreign_key "duplicate_dismissals", "users", column: "dismissed_by_id"
  add_foreign_key "enrollments", "churches"
  add_foreign_key "enrollments", "course_offerings"
  add_foreign_key "enrollments", "people"
  add_foreign_key "event_occurrences", "churches"
  add_foreign_key "event_occurrences", "events"
  add_foreign_key "events", "campuses"
  add_foreign_key "events", "churches"
  add_foreign_key "events", "forms", column: "registration_form_id"
  add_foreign_key "events", "ministries"
  add_foreign_key "events", "users", column: "organizer_id"
  add_foreign_key "form_fields", "churches"
  add_foreign_key "form_fields", "forms"
  add_foreign_key "form_submissions", "churches"
  add_foreign_key "form_submissions", "forms"
  add_foreign_key "form_submissions", "people"
  add_foreign_key "form_submissions", "users"
  add_foreign_key "forms", "churches"
  add_foreign_key "group_join_requests", "churches"
  add_foreign_key "group_join_requests", "groups"
  add_foreign_key "group_join_requests", "people"
  add_foreign_key "group_join_requests", "users", column: "decided_by_id"
  add_foreign_key "group_memberships", "churches"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "people"
  add_foreign_key "groups", "churches"
  add_foreign_key "groups", "ministries"
  add_foreign_key "households", "churches"
  add_foreign_key "ministries", "churches"
  add_foreign_key "ministry_leaderships", "churches"
  add_foreign_key "ministry_leaderships", "ministries"
  add_foreign_key "ministry_leaderships", "users"
  add_foreign_key "people", "churches"
  add_foreign_key "people", "households"
  add_foreign_key "people", "people", column: "merged_into_id"
  add_foreign_key "person_imports", "churches"
  add_foreign_key "person_imports", "users", column: "created_by_id"
  add_foreign_key "platform_sessions", "platform_admins"
  add_foreign_key "position_needs", "churches"
  add_foreign_key "position_needs", "positions"
  add_foreign_key "position_qualifications", "churches"
  add_foreign_key "position_qualifications", "people"
  add_foreign_key "position_qualifications", "positions"
  add_foreign_key "positions", "churches"
  add_foreign_key "positions", "teams"
  add_foreign_key "prayer_assignments", "churches"
  add_foreign_key "prayer_assignments", "prayer_requests"
  add_foreign_key "prayer_assignments", "users"
  add_foreign_key "prayer_requests", "churches"
  add_foreign_key "prayer_requests", "form_submissions"
  add_foreign_key "prayer_requests", "people"
  add_foreign_key "prayer_requests", "users", column: "created_by_id"
  add_foreign_key "projects", "churches"
  add_foreign_key "registrations", "churches"
  add_foreign_key "registrations", "event_occurrences"
  add_foreign_key "registrations", "form_submissions"
  add_foreign_key "registrations", "people"
  add_foreign_key "roles", "churches"
  add_foreign_key "segments", "churches"
  add_foreign_key "segments", "users", column: "created_by_id"
  add_foreign_key "service_occurrences", "churches"
  add_foreign_key "service_occurrences", "worship_services"
  add_foreign_key "session_attendances", "churches"
  add_foreign_key "session_attendances", "course_sessions"
  add_foreign_key "session_attendances", "enrollments"
  add_foreign_key "sessions", "churches"
  add_foreign_key "sessions", "users"
  add_foreign_key "special_sundays", "churches"
  add_foreign_key "taggings", "churches"
  add_foreign_key "taggings", "people"
  add_foreign_key "taggings", "tags"
  add_foreign_key "tags", "churches"
  add_foreign_key "tasks", "churches"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users", column: "created_by_id"
  add_foreign_key "tasks", "users", column: "owner_id"
  add_foreign_key "team_memberships", "churches"
  add_foreign_key "team_memberships", "people"
  add_foreign_key "team_memberships", "teams"
  add_foreign_key "teams", "churches"
  add_foreign_key "teams", "ministries"
  add_foreign_key "touchpoints", "churches"
  add_foreign_key "touchpoints", "people"
  add_foreign_key "touchpoints", "users", column: "author_id"
  add_foreign_key "user_roles", "churches"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "users", "churches"
  add_foreign_key "users", "people"
  add_foreign_key "worship_services", "campuses"
  add_foreign_key "worship_services", "churches"
end
