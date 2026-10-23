module ActiveRecordImporter
  ##
  # Loads the existing records matched by the find options of a whole
  # chunk with a single query per distinct set of find columns, so that
  # upsert/error_duplicate do not have to query the database once per row.
  #
  # Instances built during the chunk can be registered too, so duplicates
  # within the same chunk resolve to the same instance.
  ##
  class RecordPreloader
    attr_reader :importable

    def initialize(importable)
      @importable = importable
      @records = {}
      @preloaded_column_sets = []
    end

    def preload(find_attributes_list)
      find_attributes_list.compact.reject(&:blank?).group_by(&:keys).each do |columns, list|
        load_records(columns, list)
      end
      self
    end

    def find(find_attributes)
      return if find_attributes.blank?

      key = key_for(find_attributes)
      return @records[key] if @records.key?(key)

      # Fallback for callers that did not preload this set of columns
      @records[key] = importable.find_by(find_attributes)
    end

    def register(find_attributes, instance)
      @records[key_for(find_attributes)] = instance
    end

    private

    def load_records(columns, find_attributes_list)
      return if @preloaded_column_sets.include?(columns)
      @preloaded_column_sets << columns

      conditions = columns.each_with_object({}) do |column, hash|
        hash[column] = find_attributes_list.map { |attrs| attrs[column] }.uniq
      end

      importable.where(conditions).each do |record|
        attrs = columns.each_with_object({}) { |c, h| h[c] = record.read_attribute(c) }
        @records[key_for(attrs)] ||= record
      end

      find_attributes_list.each do |attrs|
        key = key_for(attrs)
        @records[key] = nil unless @records.key?(key)
      end
    end

    def key_for(find_attributes)
      find_attributes.sort_by { |column, _| column.to_s }.map do |column, value|
        [column.to_sym, cast(column, value)]
      end
    end

    def cast(column, value)
      return value unless importable.respond_to?(:type_for_attribute)
      importable.type_for_attribute(column.to_s).cast(value)
    end
  end
end
