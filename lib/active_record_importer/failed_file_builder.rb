module ActiveRecordImporter
  class FailedFileBuilder
    attr_reader :import
    attr_accessor :failed_rows

    def initialize(import)
      @import = import
      @failed_rows = []
    end
  
    def build
      return if failed_rows.blank?

      create_or_append_to_csv
      create_import_failed_file
      destroy_temp_file
    end

    private

    def create_or_append_to_csv
      puts 'TEST!!!'
      if import.failed_file.present?
        puts 'APPEND!!!!'
        append_rows_to_file
      else
        puts 'WRITE!!!!'
        write_csv_file
      end
    end

    def write_csv_file
      CSV.open(temp_file_path, 'wb') do |csv|
        csv << failed_rows.first.keys
        insert_failed_rows(csv)
      end
    end

    def append_rows_to_file
      return if import.failed_file.blank?
      CSV.open(import.failed_file_path, 'a+') do |csv|
        insert_failed_rows(csv)
      end
    end


    def insert_failed_rows(csv)
      failed_rows.each do |hash|
        csv << hash.values
      end
    end

    def destroy_temp_file
      return unless File.exists?(temp_file_path)
      FileUtils.rm(temp_file_path)
    end

    def temp_file_path
      "/tmp/#{target_file_name}"
    end

    def target_file_name
      "failed_file_#{import.id}.csv"
    end

    def create_import_failed_file
      return if import.failed_file.present?
      File.open(temp_file_path) do |file|
        import.failed_file = file

        # I forced to save it as 'text/csv' because
        # the file is being saved as 'text/x-pascal'
        # and I still have no idea why?!?

        import.failed_file_content_type = 'text/csv'
        import.save!
      end

    end
  end
end
