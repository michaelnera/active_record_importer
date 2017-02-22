module ActiveRecordImporter
  class InstanceBuilder
    attr_reader :attributes, :find_attributes, :import

    def initialize(import, find_attributes, attributes)
      @import = import
      @find_attributes = find_attributes
      @attributes = attributes
    end

    def build
      instance = initialize_instance
      process_data(instance)
    end

    private

    delegate :insert_method, to: :import

    def initialize_instance
      return klass.new if insert_method.insert?

      fail Errors::MissingFindByOption if find_attributes.blank?
      klass.find_or_initialize_by(find_attributes)
    end

    def klass
      import.resource.safe_constantize
    end

    delegate :import_options, to: :klass
    delegate :before_save, to: :import_options

    def process_data(instance)
      fail Errors::DuplicateRecord if error_duplicate?

      before_save_callback(instance)
      assign_attrs_and_save!(instance)
    end

    def before_save_callback(instance)
      return if before_save.blank?
      ImportCallbacker.new(instance, before_save).call
    end

    def assign_attrs_and_save!(instance)
      instance.attributes = attributes
      instance.save!
      instance
    end

    def error_duplicate?(instance)
      instance.persisted? && insert_method.error_duplicate?
    end
  end
end
