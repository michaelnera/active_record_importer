module ActiveRecordImporter
  class FailedFileBuilder
    attr_reader :import
    attr_accessor :failed_rows

    def initialize(import)
      @import = import
    end

    def write(failed_row = {})
      return if failed_row.blank?

      if File.exists?(temp_failed_file_path)
        File.open(temp_failed_file_path, 'a') do |file|
          file.write failed_row.values.to_csv
        end
      else
        File.open(temp_failed_file_path, 'w') do |file|
          file.write failed_row.keys
          file.write failed_row.values.to_csv
        end
      end
    end

    private

    def temp_failed_file_path
      "/tmp/#{target_file_name}"
    end

    def target_file_name
      "failed_file_#{import.id}.csv"
    end
  end
end
