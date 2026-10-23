module ActiveRecordImporter
  class InstanceBuilder
    include Virtus.model

    attribute :importable, ActiveRecord::Base
    attribute :insert_method, String, default: 'insert'
    attribute :instance_attrs, Hash, default: {}
    attribute :find_attributes, Hash, default: {}
    attribute :lookup, Object, default: :default_lookup

    ##
    # Builds (or finds) the instance for a row, runs the before_save
    # callback, assigns the attributes and validates it.
    # The instance is NOT persisted here; see BatchPersister.
    ##
    def build
      instance = initialize_instance
      process_data(instance)
    end

    private

    delegate :error_duplicate?, :insert?, to: :insert_method_inquiry

    def initialize_instance
      return importable.new if insert?

      fail Errors::MissingFindByOption if find_attributes.blank?

      existing = lookup.find(find_attributes)
      fail Errors::DuplicateRecord if existing && error_duplicate?

      existing || lookup.register(find_attributes, importable.new)
    end

    delegate :importer_options, to: :importable
    delegate :before_save, to: :importer_options

    def process_data(instance)
      before_save_callback(instance)
      assign_attrs_and_validate!(instance)
    end

    def before_save_callback(instance)
      return if before_save.blank?
      ImportCallbacker.new(instance, before_save).call
    end

    def assign_attrs_and_validate!(instance)
      instance.attributes = instance_attrs
      fail ActiveRecord::RecordInvalid.new(instance) unless instance.valid?
      instance
    end

    def insert_method_inquiry
      insert_method.inquiry
    end

    def default_lookup
      RecordPreloader.new(importable)
    end
  end
end
