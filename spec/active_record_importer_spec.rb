require 'spec_helper'

RSpec.describe ActiveRecordImporter do
  it 'has a version number' do
    expect(ActiveRecordImporter::VERSION).not_to be nil
  end

  it 'requires a Paperclip version patched for CVE-2017-0889' do
    spec = Gem::Specification.load(File.expand_path('../active_record_importer.gemspec', __dir__))
    requirement = spec.runtime_dependencies.find { |dependency| dependency.name == 'paperclip' }.requirement

    %w(3.1.4 4.2.4 5.1.0).each do |version|
      expect(requirement.satisfied_by?(Gem::Version.new(version))).to be false
    end
    %w(5.2.0 6.1.0).each do |version|
      expect(requirement.satisfied_by?(Gem::Version.new(version))).to be true
    end
  end

  it 'does not register URI attachment adapters by default' do
    adapters = Paperclip.io_adapters.registered_handlers.map(&:first)

    expect(adapters).not_to include(Paperclip::UriAdapter, Paperclip::HttpUrlProxyAdapter)
  end

  it 'still accepts local CSV files as attachments' do
    path = csv_file([{ first_name: 'Jane' }])

    File.open(path) do |file|
      expect(Paperclip.io_adapters.handler_for(file)).to eq(Paperclip::FileAdapter)
    end
  end
end
