module ActiveRecordImporter
  ##
  # Imports one chunk of csv rows:
  #
  #   1. builds the attributes of every row
  #   2. preloads, in one query, the records matched by the find options
  #   3. builds and validates an instance for every row
  #   4. persists the valid instances in bulk (see BatchPersister)
  #   5. writes the failed rows (with their errors) and updates the counters
  ##
  class BatchImporter
    include Virtus.model

    attribute :importable
    attribute :import
    attribute :data, Array, default: []

    def process!
      @imported_count, @failed_count = 0, 0

      processors = build_processors
      persist(processors)
      record_results(processors)
      set_import_count
    end

    private

    def build_processors
      processors = rows.map { |row_attrs| build_processor(row_attrs) }
      processors.each(&:prepare)
      lookup.preload(processors.map(&:find_attributes_for_lookup))
      processors.each(&:build)
      processors
    end

    def rows
      data.reject(&:blank?).map { |row_attrs| row_attrs.to_hash.symbolize_keys }
    end

    def build_processor(row_attrs)
      DataProcessor.new(
        import: import,
        importable: importable,
        row_attrs: row_attrs,
        lookup: lookup
      )
    end

    def lookup
      @lookup ||= RecordPreloader.new(importable)
    end

    def persist(processors)
      BatchPersister.new(
        importable: importable,
        processors: processors.select(&:ready?)
      ).persist!
    end

    def record_results(processors)
      processors.each do |processor|
        if processor.failed?
          write_failed_row(processor.row_attrs, processor.row_errors)
          @failed_count += 1
        else
          @imported_count += 1
        end
      end
    end

    def set_import_count
      return unless import

      import.class.update_counters(
        import.id,
        imported_rows: @imported_count,
        failed_rows: @failed_count
      )
    end

    def failed_file
      return unless import
      @failed_file ||= FailedFileBuilder.new(import)
    end

    def write_failed_row(row_attrs, errors)
      return puts errors.inspect unless failed_file
      failed_file.write(row_attrs.merge(import_errors: errors))
    end
  end
end
