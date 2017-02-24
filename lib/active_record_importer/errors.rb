module ActiveRecordImporter
  module Errors
    class InvalidTransition < StandardError
      def initialize
        super 'Transition is invalid'
      end
    end

    class MissingFindByOption < StandardError
      def initialize
        super 'Find by option for your csv is missing or incorrect.'
      end
    end

    class DuplicateRecord < StandardError
      def initialize
        super 'Duplicate record found!'
      end
    end
  end
end
