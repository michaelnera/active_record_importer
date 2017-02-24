module ActiveRecordImporter
  module Attribute
    class AttributesBuilder
      include Attribute::Helpers

      attr_reader :importable, :row_attrs, :processed_attrs

      delegate :importer_options, to: :importable
      delegate :importable_columns,
               :default_attributes,
               :find_assoc_opts,
               to: :importer_options

      def initialize(importable, row_attrs)
        @importable = importable
        @row_attrs = row_attrs
        @processed_attrs = {}
      end

      def build
        force_encode_attributes
        fetch_time_attributes
        processed_attrs
      end

      private

      def default_attrs
        def_attrs = { importing: true }
        default_attributes.each do |key, value|
          def_attrs[key] = fetch_value(value)
        end
      end

      def force_encode_attributes
        @processed_attrs = force_utf8_encode(merged_attributes)
      end

      def fetch_time_attributes
        @processed_attrs.merge!(time_attributes(processed_attrs))
      end

      def fetch_value(value)
        case value
          when Proc
            value.call(row_attrs)
          when Symbol
            importable.send(value, row_attrs)
          else
            value
        end
      end

      def merged_attributes
        attributes = row_attrs.slice(*importable_columns)
        row_attrs = attributes.inject({}) do |row_attrs, key_value|
          row_attrs[key_value.first] = key_value.last if key_value.last.present?
          row_attrs
        end
        default_attrs.merge(row_attrs)
      end

      def has_column?(column)
        return if column.blank?
        importable_columns.include?(column.to_sym)
      end
    end
  end
end
