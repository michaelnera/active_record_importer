##
# Minimal stand-in for the host application's Import model
# (the one described in the README), without Paperclip.
##
class Import < ActiveRecord::Base
  store :properties, accessors: %i(insert_method find_options batch_size)

  attr_accessor :execute_on_create

  validates :resource, presence: true

  def execute!
    resource_class.import!(object: self, execute: true)
  end

  def resource_class
    resource.safe_constantize
  end

  def import_file
    file.path
  end

  attr_accessor :file

  # Mimics Paperclip: receives the generated failed csv and keeps its content
  def failed_file=(io)
    self.failed_file_content = io.read
  end

  def failed_csv
    CSV.parse(failed_file_content.to_s, headers: true)
  end
end

##
# Importable model with validations, a unique DB index that is NOT
# backed by a model validation (employee_no), and ActiveRecord callbacks.
##
class User < ActiveRecord::Base
  include ActiveRecordImporter::Importable

  store :properties, accessors: %i(nickname department)

  validates :first_name, presence: true
  validates :email, presence: true, format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :age, numericality: { greater_than: 0 }, allow_nil: true

  after_save :bump_imports_count

  class << self
    attr_accessor :after_save_log, :state_log

    def reset_logs!
      self.after_save_log = []
      self.state_log = []
    end
  end
  reset_logs!

  # Fake state machine API, enough for TransitionProcessor
  Transition = Struct.new(:from, :to, :event)

  def state_transitions
    [
      Transition.new('pending', 'active', :activate),
      Transition.new('active', 'archived', :archive)
    ]
  end

  def state_was
    attribute_was('state')
  end

  def activate
    update_column(:state, 'active')
    self.class.state_log << [id, 'active']
  end

  def archive
    update_column(:state, 'archived')
    self.class.state_log << [id, 'archived']
  end

  def self.member_role(_row)
    'member'
  end

  private

  def bump_imports_count
    update_column(:imports_count, imports_count.to_i + 1)
  end
end

##
# Second importable model: makes sure options are not shared between models
##
class Account < ActiveRecord::Base
  include ActiveRecordImporter::Importable
  self.table_name = 'users'

  acts_as_importable insert_method: 'upsert', find_options: %i(email)
end

##
# Model that never called acts_as_importable
##
class Plain < ActiveRecord::Base
  include ActiveRecordImporter::Importable
  self.table_name = 'users'
end
