module ActiveRecordImporter
  module Importable
    module ClassMethods
      def active_record_importer(options = {})
        class << self
          attr_reader :importer_options
        end

        extend ActiveRecordImporter::Importable
        include ActiveRecordImporter::Importable

        @importer_options = OptionsBuilder.build(
            options.merge(
                importable_columns: all_columns + store_accessors(options) - excluded_columns(options)
            ))
      end

      def included(base)
        base.send :extend, ClassMethods
      end
    end

    included do
      ::IMPORTABLES << self.name unless ::IMPORTABLES.include?(self.name)
      attr_accessor :importing
    end

    private

    def all_columns
      return [] unless (self.respond_to?(:table_exists?) && self.table_exists?)
      self.columns.map { |column| column.name.to_sym }
    end

    def store_accessors(options = {})
      options.fetch(:store_accessors, [])
    end

    def importable_columns
      importer_options.importable_columns
    end

    def excluded_columns(options = {})
      columns = [:id]
      columns + options.fetch(:exclude_columns, [])
    end
  end
end