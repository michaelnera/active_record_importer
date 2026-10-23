$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'active_record'
require 'active_record_importer'

require_relative 'support/database'
require_relative 'support/csv_helper'
require_relative 'support/query_counter'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.include CsvHelper
  config.include QueryCounter

  config.before(:suite) do
    Database.connect!
    Database.load_schema!
    # Models call acts_as_importable, which reads the table columns,
    # so they can only be loaded once the schema exists
    require_relative 'support/models'
  end

  config.before(:each) do
    Database.clean!
    User.reset_logs!
  end

  config.after(:each) do
    Array(@csv_files).each(&:close!)
  end
end
