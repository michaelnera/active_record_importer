require 'spec_helper'

RSpec.describe ActiveRecordImporter::OptionsBuilder do
  it 'builds importer options with defaults' do
    options = described_class.build

    expect(options.find_options).to eq([])
    expect(options.bulk_insert).to be(true)
    expect(options.csv_opts.chunk_size).to eq(500)
    expect(options.csv_opts.col_sep).to eq(',')
  end

  it 'merges csv options' do
    options = described_class.build(csv_opts: { chunk_size: 10, col_sep: '|' }, bulk_insert: false)

    expect(options.csv_opts.to_hash).to include(chunk_size: 10, col_sep: '|', force_utf8: true)
    expect(options.bulk_insert).to be(false)
  end
end
