module ActiveRecordImporter
  class ImportCallbacker
    attr_reader :object, :callback_methods

    def initialize(object, callback_methods)
      @object = object
      @callback_methods = callback_methods
    end

    def call
      case callback_methods
        when Array
          run_each_callbacks
        when Symbol
          object.send(callback)
        when Proc
          callback.call(object)
      end
    end

    private

    def run_each_callbacks
      callback_methods.each do |callback|
        object.send(callback) if callback.is_a?(Symbol)
        callback.call(object) if callback.is_a?(Proc)
      end
    end
  end
end
