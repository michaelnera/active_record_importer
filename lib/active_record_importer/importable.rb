module ActiveRecordImporter
  module Importable
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      ##
      # #acts_as_importable
      #
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

        include ActiveRecordImporter::Importable::InstanceMethods
        extend ActiveRecordImporter::Importable::SingletonMethods
      end

      def importer_options
        @@importer_options
      end

      def importable?
        false
      end

      ##
      # #import!
      #
      # This method is called in the Import instance during execution of import
      # You may also call this method without any import instance
      # e.g.
      #
      # User.import!(file: File.open(PATH_TO_FILE))
      #
      # "insert" will be the default insert method for this
      # If you want to use "upsert" or "error_duplicate",
      # define it in your importer options:
      #
      #   class User < ActiveRecord::Base
      #     acts_as_importable insert_method: 'upsert',
      #                        find_options: ['email']
      #   end
      #
      #  Or you may use:
      #  User.acts_as_importable insert_method: 'error_duplicate', find_options: ['email']
      #
      ##
      def import!(options = {})
        fail "#{self.name} is not importable" unless importable?

        import_object = options.fetch(:object, nil)
        execute = options.fetch(:execute, true)
        import_file = get_import_file(import_object, options)

        call_dispatcher(import_object, execute, import_file)
      end

      private

      def call_dispatcher(import_object = nil, execute = true, file = nil)
        ActiveRecordImporter::Dispatcher.new(
          importable: self,
          import: import_object,
          execute: execute,
          import_file: file
        ).call
      end

      def get_import_file(import, options = {})
        file = options.fetch(:file, nil) || import.try(:import_file)
        fail Errors::MissingImportFile.new unless file
        file
      end


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

    module SingletonMethods
      def importable?
        true
      end
    end
  end
end
