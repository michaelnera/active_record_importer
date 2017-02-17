require 'rails'

module ActiveRecordImporter
  class Railtie < Rails::Railtie

    initializer "active_record_importer.active_record" do |_app|
      ActiveSupport.on_load :active_record do
        include ActiveRecordImporter::Importable
      end
    end

  end
end
