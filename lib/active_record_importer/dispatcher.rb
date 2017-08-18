module ActiveRecordImporter
  class Dispatcher
    include Virtus.model

    attribute :import, Import
    attribute :importable, Class
    attribute :execute, Boolean, default: true
    attribute :import_file

    def call
      divide_and_conquer
      create_import_failed_file
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

    def queue(_collection)
      # To follow
    end

    def create_import_failed_file
      return unless File.exists?(temp_failed_file_path)
      File.open(temp_failed_file_path) do |file|
        import.failed_file = file

        # I forced to save it as 'text/csv' because
        # the file is being saved as 'text/x-pascal'
        # and I still have no idea why?!?

        import.failed_file_content_type = 'text/csv'
        import.save!
      end

      destroy_temp_failed_file
    end

    def destroy_temp_failed_file
      FileUtils.rm(temp_file_path)
    end
  end
end
