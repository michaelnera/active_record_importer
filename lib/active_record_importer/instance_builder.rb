module ActiveRecordImporter
  class InstanceBuilder
    attr_reader :attributes, :find_attributes, :import

    def initialize(import, find_attributes, attributes)
      @import = import
      @find_attributes = find_attributes
      @attributes = attributes
    end

    def build
      fail 'Find by option for your csv is missing or incorrect.' if find_attributes.blank?
      instance = klass.find_or_initialize_by(find_attributes)
      process_data(instance)
    end

    private

    def klass
      import.resource.safe_constantize
    end

    def process_data(instance)
      return insert_or_update(instance) if upsert_duplicate?(instance)
      fail 'Duplicate record'
    end

    def insert_or_update(instance)
      instance.attributes = attributes
      instance.save!
      instance
    end

    delegate :insert_method, to: :import

    def upsert_duplicate?(instance)
      instance.new_record? || insert_method.upsert?
    end
  end
end
