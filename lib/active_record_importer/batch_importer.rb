module ActiveRecordImporter
  class BatchImporter
    include Virtus.model

    attribute :import, Import
    attribute :importable
    attribute :data, Array, default: []
    attribute :failed_file, FailedFileBuilder, default: :initialize_failed_file

    def process!
      @imported_count, @failed_count = 0, 0

      data.each do |row_attrs|
        next if row_attrs.blank?
        process_row(row_attrs.symbolize_keys!)
      end

      set_import_count
      finalize_batch_import
    end

    private

    def initialize_failed_file
      return unless import
      FailedFileBuilder.new(import)
    end

    def process_row(row_attrs)
      processor =
        DataProcessor.new(
          import: import,
          importable: importable,
          row_attrs: row_attrs
        )
      return @imported_count += 1 if processor.process

      collect_failed_rows(row_attrs, processor.row_errors)
      @failed_count += 1
    end

    def set_import_count
      return unless import

      Import.update_counters(import.id, imported_rows: @imported_count)
      Import.update_counters(import.id, failed_rows: @failed_count)
    end

    def collect_failed_rows(row_attrs, errors)
      return puts errors.inspect unless failed_file
      @failed_file.failed_rows << row_attrs.merge(import_errors: errors)
    end

    def finalize_batch_import
      return unless failed_file
      @failed_file.build
    end

    delegate :importer_options, to: :importable

    def csv_options
      importer_options.csv_opts.to_hash
    end
  end
end
