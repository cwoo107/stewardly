class PersonImportJob < ApplicationJob
  queue_as :default

  # Resumes from the last committed batch on retry (see PersonImport::Importer).
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(person_import)
    return if person_import.finished?

    PersonImport::Importer.new(person_import).import!
  end
end
