# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_record_importer/version'

Gem::Specification.new do |spec|
  spec.name          = 'active_record_importer'
  spec.version       = ActiveRecordImporter::VERSION
  spec.authors       = ['Michael Nera']
  spec.email         = ['kapitan_03@yahoo.com']

  spec.summary       = 'Active Record Importer'
  spec.description   = 'Smart gem for importing CSV files to ActiveRecord models'
  spec.homepage      = 'https://github.com/michaelnera/active_record_importer'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rspec', '~> 2.99'

  spec.add_runtime_dependency 'activerecord', '>= 4.0'
  spec.add_runtime_dependency 'activesupport', '>= 4.0'
  spec.add_runtime_dependency 'enumerize', '>= 2.0', '~> 2.0.1'
  spec.add_runtime_dependency 'virtus', '>= 1.0', '~> 1.0'
  spec.add_runtime_dependency 'smarter_csv', '>= 1.0', '~> 1.0'
  spec.add_runtime_dependency 'paperclip', '>= 4.0', '~> 4.0'
end
