# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_record_importer/version'

Gem::Specification.new do |spec|
  spec.name          = "active_record_importer"
  spec.version       = ActiveRecordImporter::VERSION
  spec.authors       = ["Michael Nera"]
  spec.email         = ["kapitan_03@yahoo.com"]

  spec.summary       = "Active Record Importer"
  spec.description   = "Smart gem for importing rails models"
  spec.homepage      = "https://github.com/michaelnera/active_record_importer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
end
