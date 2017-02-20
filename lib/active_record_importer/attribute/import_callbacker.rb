module ActiveRecordImporter
  class ImportCallbacker
    attr_reader :object, :callback_methods

    def initialize(object, callback_methods)
      @object = object
      @callback_methods = callback_methods
    end

    def call
      callback_methods.each do |callback|
        object.send(callback) if callback.is_a?(Symbol)
        callback.call(object) if callback.is_a?(Proc)
      end
    end
  end
end
