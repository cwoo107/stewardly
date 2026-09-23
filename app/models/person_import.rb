# A CSV of people uploaded by staff: uploaded → mapped → queued → processing → completed/failed.
class PersonImport < ApplicationRecord
  MAX_FILE_SIZE = 5.megabytes

  belongs_to :created_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_one_attached :file

  enum :status, { pending: "pending", queued: "queued", processing: "processing", completed: "completed", failed: "failed" },
    default: :pending, validate: true

  validate :file_is_a_small_csv, on: :create
  validate :mapping_names_people, if: -> { mapping_changed? && mapping.present? }

  # The progress page refreshes itself (Turbo morph) as the job saves counts.
  broadcasts_refreshes

  scope :recent_first, -> { order(created_at: :desc) }

  def mapped_fields
    mapping.values.compact_blank
  end

  def progress_percent
    row_count.zero? ? 0 : (processed_count * 100 / row_count)
  end

  def finished?
    completed? || failed?
  end

  private
    def file_is_a_small_csv
      return errors.add(:file, "must be attached") unless file.attached?

      errors.add(:file, "must be a .csv file") unless file.filename.extension.casecmp?("csv")
      errors.add(:file, "must be smaller than 5 MB") if file.byte_size > MAX_FILE_SIZE
    end

    def mapping_names_people
      fields = mapped_fields
      errors.add(:mapping, "must include a first name and last name column") unless (%w[ first_name last_name ] - fields).empty?

      unknown = fields - PersonImport::Importer.field_keys
      errors.add(:mapping, "has unknown fields: #{unknown.join(", ")}") if unknown.any?
      errors.add(:mapping, "uses a field more than once") if fields.size != fields.uniq.size
    end
end
