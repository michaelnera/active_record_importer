require 'spec_helper'

RSpec.describe ActiveRecordImporter::FailedFileBuilder do
  let(:import) { Import.create!(resource: 'User') }
  let(:path) { "/tmp/failed_file_#{import.id}.csv" }

  subject(:builder) { described_class.new(import) }

  after { FileUtils.rm_f(path) }

  it 'writes a header row followed by the failed rows' do
    builder.write(first_name: 'Ann', email: 'ann@example.com', import_errors: 'boom')
    builder.write(first_name: 'Bob', email: 'bob@example.com', import_errors: 'bang, "quoted"')

    csv = CSV.read(path, headers: true)
    expect(csv.headers).to eq(%w(first_name email import_errors))
    expect(csv.size).to eq(2)
    expect(csv[1]['import_errors']).to eq('bang, "quoted"')
  end

  it 'ignores blank rows' do
    builder.write({})

    expect(File.exist?(path)).to be(false)
  end
end
