module ActiveRecordImporter
  class BatchImporter
    include Virtus.model

    attribute :import, Import
    attribute :importable
    attribute :data, Array, default: []

    def process!
      @imported_count, @failed_count = 0, 0

      data.each do |row_attrs|
        next if row_attrs.blank?
        process_row(row_attrs.symbolize_keys!)
      end

      set_import_count
    end

    private

    def process_row(row_attrs)
      processor =
        DataProcessor.new(
          import: import,
          importable: importable,
          row_attrs: row_attrs
        )
      return @imported_count += 1 if processor.process

      write_failed_row(row_attrs, processor.row_errors)
      @failed_count += 1
    end

    def set_import_count
      return unless import

      Import.update_counters(import.id, imported_rows: @imported_count)
      Import.update_counters(import.id, failed_rows: @failed_count)
    end

    def failed_file
      return unless import.present? || import.respond_to?(:failed_file) 
      @failed_file ||= FailedFileBuilder.new(import)
    end

    def write_failed_row(row_attrs, errors)
      return puts errors.inspect unless failed_file
      failed_file.write(row_attrs.merge(import_errors: errors))
    end

    delegate :importer_options, to: :importable

    def csv_options
      importer_options.csv_opts.to_hash
    end
  end
end
