module ActiveRecordImporter
  class FindOptionsBuilder
    include Virtus.model
    include Helpers

    attribute :resource, String
    attribute :attrs, Hash, default: {}
    attribute :find_options, String
    attribute :prefix, String

    def build
      get_find_opts
      slice_attributes
    end

    private

    def klass
      resource.safe_constantize
    end

    delegate :importer_options, to: :klass

    delegate :required_attributes, to: :importer_options

    def get_find_opts
      @options = strip_and_symbolize
      @options ||= importer_options.find_options || required_attributes
      @options
    end

    def slice_attributes
      return attrs.slice(*@options).compact if prefix.blank?

      @options.inject({}) do |attr, key|
        attr[key] = attrs[prefixed_key(key)].presence
        attr
      end.compact
    end

    def prefixed_key(key)
      "#{prefix}#{key}".to_sym
    end

    def strip_and_symbolize
      return if find_options.blank?
      find_options.split(',').map do |key|
        key.strip.to_sym
      end
    end
  end
end
