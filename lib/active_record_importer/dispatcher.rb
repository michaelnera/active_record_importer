module ActiveRecordImporter
  class Dispatcher
    attr_reader :import, :execute

    def initialize(import_id, execute = true)
      @import = Import.find(import_id)
      @execute = execute
    end

    def call
      divide_and_conquer
    end

    private

    def divide_and_conquer
      File.open(import.import_file, 'r:bom|utf-8') do |file|
        SmarterCSV.process(file, csv_options) do |collection|
          queue_or_execute(collection)
        end
      end
    end

    def csv_options
      klass = import.resource.safe_constantize
      opts = klass_csv_opts(klass)
      return opts if import.batch_size.blank? || import.batch_size < 1
      opts.merge(chunk_size: import.batch_size)
    end

    def klass_csv_opts(klass)
      klass.import_options.csv_opts.to_hash
    end

    def queue_or_execute(collection)
      process_import(collection) if execute
      queue(collection)
    end

    def process_import(collection)
      BatchImporter.new(import, collection)
    end

    def queue(collection)
      # To follow
    end
  end
end
