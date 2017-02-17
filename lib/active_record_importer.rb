require 'active_record_importer/version'

module ActiveRecordImporter
  ::IMPORTABLES = []

  autoload :Importable,     'active_record_importer/importable'
  autoload :OptionsBuilder, 'active_record_importer/options_builder'

  require 'active_record_importer/railtie' if defined?(Rails) && Rails::VERSION::MAJOR >= 3
end
