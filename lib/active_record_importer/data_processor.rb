module ActiveRecordImporter
  class DataProcessor
    attr_reader :importable, :import, :instance, :attributes,
                :row_errors, :row_attrs, :find_attributes

    delegate :importer_options,
             to: :importable

    def initialize(import, row_attrs)
      @import = import
      @importable = import.resource.safe_constantize
      @row_attrs = row_attrs
    end

    def process
      fetch_instance_attributes
      fetch_find_attributes
      create_instance
    end

    private

    def create_instance
      ActiveRecord::Base.transaction do
        begin
          @instance =
              InstanceBuilder.new(
                import, find_attributes,
                attributes_without_state_machine_attrs
              ).build

          methods_after_upsert
          true
        rescue => exception
          append_errors(exception, true)
        end
      end
    end

    def fetch_instance_attributes
      @attributes = AttributesBuilder.new(
                      importable, row_attrs
                    ).build
    rescue => exception
      append_errors(exception)
    end

    def fetch_find_attributes
      @find_attributes = FindOptionsBuilder.new(
        resource: import.resource,
        find_options: import.find_options,
        attrs: attributes
      ).build
    rescue => exception
      append_errors(exception)
    end

    def methods_after_upsert
      return if instance.blank? || !instance.persisted?

      state_transitions
      run_after_save_callbacks
    end

    delegate :after_save,
             :state_machine_attr,
             to: :importer_options

    def state_transitions
      return if state_machine_attr.blank?

      state_machine_attr.each do |attr|
        state = row_attrs[attr.to_sym]
        next if state.blank? || state == instance.send(attr)
        TransitionProcessor.new(instance, state, attr).transit
      end
    end

    def attributes_without_state_machine_attrs
      attributes.except(*state_machine_attr)
    end

    def skip_callbacks?
      after_save.blank? || instance.blank? || instance.new_record?
    end

    def run_after_save_callbacks
      return if skip_callbacks?

      ImportCallbacker.new(instance, after_save).call
    end

    def append_errors(error, rollback = false)
      return if error.blank?

      message = error.is_a?(Exception) ? error.message : error
      @row_errors = message
      fail ActiveRecord::Rollback if rollback
    end
  end
end
