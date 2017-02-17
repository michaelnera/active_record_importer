module ActiveRecordImporter
  class OptionsBuilder
    def self.build(options = {})
      ImporterOptions.new(options)
    end
  end

  class CsvOptions
    include Virtus.value_object

    values do
      attribute :convert_values_to_numeric, Hash[Symbol => Array],
                default: { only: [:metric_amount] }
      attribute :remove_empty_values, Boolean, default: false
      attribute :comment_regexp, Regexp, default: Regexp.new(/^#=>/)
      attribute :force_utf8, Boolean, default: true
    end
  end

  class ImporterOptions
    include Virtus.model

    attribute :required_attributes, Array
    attribute :find_options, Array
    attribute :exclude_from_find_options, Array
    attribute :import_method, Symbol, default: :create
    attribute :scope, Symbol
    attribute :importable_columns, Array
    attribute :default_attributes, Hash
    attribute :csv_opts, CsvOptions, default: CsvOptions.new
    attribute :find_assoc_opts, Hash
    attribute :before_assign_of_attrs, Proc
    attribute :after_save_callbacks, Array
    attribute :state_machine_attr, Array
  end
end
