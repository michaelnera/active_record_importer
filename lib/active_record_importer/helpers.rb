module ActiveRecordImporter
  module Helpers

    def parse_datetime(datetime = nil)
      return if datetime.blank?
      Time.parse(datetime)
    end

    def force_utf8_encode(data = {})
      return data if data.blank?

      data.keys.each do |key|
        data[key] = data[key].force_encoding('UTF-8') if data[key].is_a?(String)
      end

      data
    end

    def time_attributes(data = {})
      attrs = {}
      attrs[:created_at] = parse_datetime(data[:created_at]) || Time.now
      attrs[:updated_at] = parse_datetime(data[:updated_at]) || attrs[:created_at]
      attrs
    end
  end
end
