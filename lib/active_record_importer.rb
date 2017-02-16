require "active_record_importer/version"
require "active_record"
::IMPORTABLES = []
ActiveRecord::Base.extend(ActiveRecordImporter::Importable::ClassMethods)
