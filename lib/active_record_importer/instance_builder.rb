module ActiveRecordImporter
  class InstanceBuilder
    include Virtus.model

    attribute :importable, ActiveRecord::Base
    attribute :insert_method, String, default: 'insert'
    attribute :instance_attrs, Hash, default: {}
    attribute :find_attributes, Hash, default: {}

    def build
      instance = initialize_instance
      process_data(instance)
    end

    private

    delegate :error_duplicate, :insert?, to: :insert_method_inquiry

    def initialize_instance
      return importable.new if insert?

      fail Errors::MissingFindByOption if find_attributes.blank?
      importable.find_or_initialize_by(find_attributes)
    end

    delegate :importer_options, to: :importable
    delegate :before_save, to: :importer_options

    def process_data(instance)
      fail Errors::DuplicateRecord if error_duplicate?(instance)

      before_save_callback(instance)
      assign_attrs_and_save!(instance)
    end

    def before_save_callback(instance)
      return if before_save.blank?
      ImportCallbacker.new(instance, before_save).call
    end

    def assign_attrs_and_save!(instance)
      instance.attributes = instance_attrs
      instance.save!
      instance
    end

    def insert_method_inquiry
      insert_method.inquiry
    end

    def error_duplicate?(instance)
      instance.persisted? && error_duplicate?
    end
  end
end
