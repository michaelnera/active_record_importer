module ActiveRecordImporter
  class BatchImporter

    attr_reader :data, :import

    def initialize(import, data)
      @import = import
      @data = data
    end

    def process!
      @imported_count, @failed_count = 0, 0

      data.each do |row|
        next if row.blank?
        processor = DataProcessor.new(import, row.symbolize_keys!)
        processor.process ? @imported_count += 1 : @failed_count += 1
      end

      set_import_count
    end

    private

    def set_import_count
      Import.update_counters(import.id, imported_rows: @imported_count)
      Import.update_counters(import.id, failed_rows: @failed_count)
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
