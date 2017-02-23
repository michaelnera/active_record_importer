module ActiveRecordImporter
  module Importable
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      ##
      # Make a model importable
      # This will allow a model to use the importer
      #
      #   class User < ActiveRecord::Base
      #     acts_as_importable
      #   end
      #
      # You may also add options:
      #   class User < ActiveRecord::Base
      #     acts_as_importable default_attributes: {first_name: 'Michael', surname: 'Nera'}
      #   end
      ##
      def acts_as_importable(options = {})
        @@importer_options = OptionsBuilder.build(options.merge(allowed_columns_hash(options)))
        ::IMPORTABLES << self.name unless ::IMPORTABLES.include?(self.name)

        include ActiveRecordImporter::Importable::InstanceMethods
      end

      def importer_options
        @@importer_options
      end

      def import!(import_object, execute = true)
        ActiveRecordImporter::Dispatcher.new(
          import_object.id, execute).call
      end

      private

      def allowed_columns_hash(options = {})
        {
          importable_columns: allowed_columns(options)
        }
      end

      def allowed_columns(options = {})
        all_columns + store_accessors(options) - excluded_columns(options)
      end

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

    module InstanceMethods
      attr_accessor :importing

      def importing?
        @importing ||= false
      end
    end
  end
end
