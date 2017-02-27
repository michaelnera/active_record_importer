module ActiveRecordImporter
  class Dispatcher
    include Virtus.model

    attribute :import, Import
    attribute :importable, Class
    attribute :execute, Boolean, default: true
    attribute :import_file

    def call
      divide_and_conquer
    end

    private

    def divide_and_conquer
      File.open(import_file, 'r:bom|utf-8') do |file|
        SmarterCSV.process(file, csv_options) do |collection|
          queue_or_execute(collection)
        end
      end
      true
    end

    def csv_options
      opts = klass_csv_opts
      return opts if import.nil? || import.batch_size.blank?
      opts.merge(chunk_size: import.batch_size)
    end

    def klass_csv_opts
      importable.importer_options.csv_opts.to_hash
    end

    def queue_or_execute(collection)
      process_import(collection) if execute
      queue(collection)
    end

    def process_import(collection)
      BatchImporter.new(
        import: import,
        importable: importable,
        data: collection
      ).process!
    end

    def queue(collection)
      # To follow
    end
  end
end
