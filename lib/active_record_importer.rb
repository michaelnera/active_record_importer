require 'active_record_importer/version'
require 'active_support/core_ext/module'
require 'virtus'
require 'enumerize'
require 'smarter_csv'
require 'paperclip'

module ActiveRecordImporter
  extend ActiveSupport::Autoload

  ::IMPORTABLES = []

  autoload :BatchImporter,        'active_record_importer/batch_importer'
  autoload :DataProcessor,        'active_record_importer/data_processor'
  autoload :Dispatcher,           'active_record_importer/dispatcher'
  autoload :Errors,               'active_record_importer/errors'
  autoload :Importable,           'active_record_importer/importable'
  autoload :InstanceBuilder,      'active_record_importer/instance_builder'
  autoload :OptionsBuilder,       'active_record_importer/options_builder'
  autoload :AttributesBuilder,    'active_record_importer/attributes_builder'
  autoload :FindOptionsBuilder,   'active_record_importer/find_options_builder'
  autoload :TransitionProcessor,  'active_record_importer/transition_processor'
  autoload :ImportCallbacker,     'active_record_importer/import_callbacker'
  autoload :Helpers,              'active_record_importer/helpers'

  require 'active_record_importer/railtie' if defined?(Rails) && Rails::VERSION::MAJOR >= 3
end
