module ActiveRecordImporter
  class BatchImporter

    attr_reader :data, :import, :failed_file, :processor

    def initialize(import, data)
      @import = import
      @data = data
      @failed_file = FailedFileBuilder.new(import)
    end

    def process!
      @imported_count, @failed_count = 0, 0
      data.each do |row|
        next if row.blank?
        process_row(row.symbolize_keys!)
      end

      set_import_count
      finalize_batch_import
    end

    private

    def process_row(row)
      processor = DataProcessor.new(import, row)
      return @imported_count += 1 if processor.process

      @failed_file.failed_rows << row.merge(import_errors: processor.row_errors)
      @failed_count += 1
    end

    def set_import_count
      Import.update_counters(import.id, imported_rows: @imported_count)
      Import.update_counters(import.id, failed_rows: @failed_count)
    end

    def finalize_batch_import
      @failed_file.build
    end

    def importable
      import.resource.safe_constantize
    end

    delegate :importer_options, to: :importable

    def csv_options
      importer_options.csv_opts.to_hash
    end
  end
end
