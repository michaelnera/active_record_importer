module ActiveRecordImporter
  ##
  # Persists the already validated instances of a chunk.
  #
  # When possible, new records are inserted with a single bulk INSERT and
  # existing records are updated with a single bulk upsert on the primary
  # key (through activerecord-import). If a bulk statement fails because of
  # a database level error (e.g. a unique index), the affected group is
  # retried row by row inside savepoints so only the offending rows fail.
  #
  # When importer callbacks need a persisted instance (after_save or
  # state_machine_attr), or bulk insert is disabled for the model, every
  # row is saved individually inside one transaction per chunk.
  ##
  class BatchPersister
    include Virtus.model

    attribute :importable, Class
    attribute :processors, Array, default: []

    def persist!
      return if processors.empty?

      importable.transaction do
        bulk? ? persist_in_bulk : persist_each(processors)
      end
    end

    private

    delegate :importer_options, to: :importable
    delegate :after_save, :state_machine_attr, :bulk_insert, to: :importer_options

    def bulk?
      bulk_insert != false && !callbacks_required? && bulk_import_supported?
    end

    def callbacks_required?
      after_save.present? || state_machine_attr.present?
    end

    def bulk_import_supported?
      importable.respond_to?(:bulk_import)
    end

    def bulk_update_supported?
      connection = importable.connection
      connection.respond_to?(:supports_on_duplicate_key_update?) &&
        connection.supports_on_duplicate_key_update?
    end

    def persist_in_bulk
      new_processors, existing_processors =
        processors.partition { |processor| processor.instance.new_record? }

      bulk_insert_records(new_processors)
      bulk_update_records(existing_processors)
    end

    def bulk_insert_records(group)
      return if group.empty?
      bulk_import(group, validate: false)
    end

    def bulk_update_records(group)
      return if group.empty?
      return persist_each(group) unless bulk_update_supported?

      columns = changed_columns(group)
      return if columns.empty?

      bulk_import(group, validate: false, on_duplicate_key_update: columns)
    end

    def bulk_import(group, options)
      instances = group.map(&:instance).uniq

      importable.transaction(requires_new: true) do
        importable.bulk_import(instances, options)
      end
    rescue ActiveRecord::ActiveRecordError
      persist_each(group)
    end

    def changed_columns(group)
      columns = group.flat_map { |processor| processor.instance.changed }.uniq
      (columns - Array(importable.primary_key).map(&:to_s)).map(&:to_sym)
    end

    def persist_each(group)
      group.each do |processor|
        begin
          importable.transaction(requires_new: true) do
            processor.instance.save!
            processor.after_persist
          end
        rescue => exception
          processor.mark_failed(exception)
        end
      end
    end
  end
end
