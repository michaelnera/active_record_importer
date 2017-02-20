module ActiveRecordImporter
  class Import < ActiveRecord::Base
    store :properties, accessors: %i(insert_method find_options batch_size)

    enumerize :insert_method,
              in: %w(insert upsert error_duplicate),
              default: :upsert

    has_attached_file :file

    attr_accessor :execute_on_create

    validate :check_presence_of_find_options
    validates_attachment :file,
                         content_type: {
                             content_type: %w(text/plain text/csv)
                         }

    accepts_nested_attributes_for :import_options, allow_destroy: true

    def import!
      ActiveRecordImporter::Dispatcher.new(
        self.id, execute_on_create
      ).call
    end

    def batch_size
      super.to_i
    end

    private

    def check_presence_of_find_options
      return if insert_method.insert?
      errors.add(:find_options, "can't be blank") if find_options.blank?
    end

    ##
    # Override this if you prefer have
    # a private permissions or you have
    # private methods for reading files
    ##
    def import_file
      local_path? ? file.path : file.url
    end

    private

    def local_path?
      File.exist? import_file.file.path
    end
  end
end