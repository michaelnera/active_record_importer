module ActiveRecordImporter
  class OptionsBuilder
    def self.build(options = {})
      ImporterOptions.new(options)
    end
  end

  #
  # SmarterCSV is used to process the csv file
  # https://github.com/tilo/smarter_csv
  # I used some of it's options
  # Please refer to it's documentation
  #
  class CsvOptions
    include Virtus.value_object

    values do
      attribute :convert_values_to_numeric
      attribute :value_converters, Hash, default: nil
      attribute :remove_empty_values, Boolean, default: false
      attribute :comment_regexp, Regexp, default: Regexp.new(/^#=>/)
      attribute :force_utf8, Boolean, default: true
      attribute :chunk_size, Integer, default: 500
      attribute :col_sep, String, default: ','
    end
  end

  #
  # Import Option for every IMPORTABLE model
  #
  class ImporterOptions
    include Virtus.model

    attribute :find_options, Array, default: []
    attribute :exclude_from_find_options, Array
    attribute :scope, Symbol
    attribute :insert_method, String
    attribute :importable_columns, Array
    attribute :default_attributes, Hash
    attribute :csv_opts, CsvOptions, default: CsvOptions.new
    attribute :find_assoc_opts, Hash
    attribute :before_save
    attribute :after_save
    attribute :state_machine_attr, Array
  end
end
