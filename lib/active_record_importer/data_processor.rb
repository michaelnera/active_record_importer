module ActiveRecordImporter
  class DataProcessor
    include Virtus.model

    attribute :import, Import
    attribute :importable, Class
    attribute :insert_method, String, default: :set_insert_method
    attribute :row_attrs, Hash
    attribute :instance_attrs, Hash
    attribute :find_options, String, default: :set_find_options
    attribute :find_attributes, Hash
    attribute :row_errors, Array
    attribute :instance

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
              importable: importable,
              insert_method: insert_method,
              find_attributes: find_attributes,
              instance_attrs: attributes_without_state_machine_attrs
            ).build

          methods_after_upsert
          true
        rescue => exception
          append_errors(exception, true)
        end
      end
    end

    def fetch_instance_attributes
      @instance_attrs = Attribute::AttributesBuilder.new(
        importable, row_attrs
      ).build
    rescue => exception
      append_errors(exception)
    end

    def fetch_find_attributes
      @find_attributes = Attribute::FindOptionsBuilder.new(
        importable: importable,
        find_options: find_options,
        attrs: instance_attrs
      ).build
    rescue => exception
      append_errors(exception)
    end

    def methods_after_upsert
      return if instance.blank? || !instance.persisted?

      state_transitions
      run_after_save_callbacks
    end

    delegate :importer_options,
             to: :importable

    delegate :after_save, :state_machine_attr,
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
      instance_attrs.except(*state_machine_attr)
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

    def set_insert_method
      @insert_method = import.try(:insert_method)
      @insert_method ||= importer_options.insert_method
      @insert_method ||= 'insert'
    end

    def set_find_options
      import.try(:find_options) || importer_options.find_options.join(',')
    end
  end
end
