module ActiveRecordImporter
  class TransitionProcessor

    attr_reader :object, :column, :new_state

    def initialize(object, new_state, column = :state)
      @object = object
      @new_state = new_state
      @column = column
    end

    def transit
      fire_event!(transit_event)
      true
    end

    private

    def fire_event!(event)
      fail Errors::InvalidTransition if event.blank?
      object.send(event)
    end

    def transit_event
      state_transitions.each do |trans|
        return trans.event if trans.from == state_was && trans.to == new_state
      end
      nil
    end

    def state_transitions
      object.send("#{column}_transitions")
    end

    def state_was
      object.send("#{column}_was")
    end
  end
end
