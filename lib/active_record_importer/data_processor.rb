module ActiveRecordImporter
  ##
  # Prepares a single csv row: builds its attributes and find attributes,
  # builds and validates the instance, and keeps the row errors.
  # Persistence happens later, for the whole chunk, in BatchPersister.
  ##
  class DataProcessor
    include Virtus.model

    attribute :importable, Class
    attribute :import
    attribute :insert_method, String, default: :set_insert_method
    attribute :row_attrs, Hash
    attribute :instance_attrs, Hash
    attribute :find_options, String, default: :set_find_options
    attribute :find_attributes, Hash
    attribute :row_errors, String
    attribute :instance
    attribute :lookup, Object, default: :default_lookup

    def process
      prepare
      build
    end

    ##
    # Step 1: build the attributes used for the instance and the lookup
    ##
    def prepare
      fetch_instance_attributes
      fetch_find_attributes
      !failed?
    end

    ##
    # Step 2: build and validate the instance
    ##
    def build
      return false if failed?

      @instance =
        InstanceBuilder.new(
          importable: importable,
          insert_method: insert_method,
          find_attributes: find_attributes,
          instance_attrs: attributes_without_state_machine_attrs,
          lookup: lookup
        ).build
      true
    rescue => exception
      append_errors(exception)
      false
    end

    ##
    # Find attributes that need to be preloaded for this row
    ##
    def find_attributes_for_lookup
      return if failed? || insert_method.inquiry.insert?
      find_attributes
    end

    ##
    # Called once the instance is persisted (per-row mode only)
    ##
    def after_persist
      methods_after_upsert
    end

    def mark_failed(error)
      append_errors(error)
    end

    def failed?
      row_errors.present?
    end

    def ready?
      !failed? && instance.present?
    end

    private

    def fetch_instance_attributes
      @instance_attrs = Attribute::AttributesBuilder.new(
        importable, row_attrs
      ).build
    rescue => exception
      append_errors(exception)
    end

    def fetch_find_attributes
      return if failed?

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
      instance_attrs.except(*Array(state_machine_attr))
    end

    def skip_callbacks?
      after_save.blank? || instance.blank? || instance.new_record?
    end

    def run_after_save_callbacks
      return if skip_callbacks?

      ImportCallbacker.new(instance, after_save).call
    end

    def append_errors(error)
      return if error.blank?

      @row_errors = error.is_a?(Exception) ? error.message : error.to_s
    end

    def set_insert_method
      @insert_method = import.try(:insert_method)
      @insert_method ||= importer_options.insert_method
      @insert_method ||= 'insert'
    end

    def set_find_options
      import.try(:find_options) || importer_options.find_options.join(',')
    end

    def default_lookup
      RecordPreloader.new(importable)
    end
  end
end
