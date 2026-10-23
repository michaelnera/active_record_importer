require 'spec_helper'

RSpec.describe ActiveRecordImporter::Attribute::AttributesBuilder do
  before { User.acts_as_importable default_attributes: { role: 'member' } }

  def build(row)
    described_class.new(User, row).build
  end

  it 'keeps only importable columns with present values' do
    attrs = build(first_name: 'Ann', last_name: '', email: nil, id: 5, bogus: 'x')

    expect(attrs).to include(first_name: 'Ann', role: 'member', importing: true)
    expect(attrs.keys).not_to include(:last_name, :email, :id, :bogus)
  end

  it 'adds created_at and updated_at' do
    attrs = build(first_name: 'Ann')

    expect(attrs[:created_at]).to be_a(Time)
    expect(attrs[:updated_at]).to eq(attrs[:created_at])
  end

  it 'parses timestamps from the row' do
    attrs = build(first_name: 'Ann', created_at: '2021-05-06 07:08:09')

    expect(attrs[:created_at]).to eq(Time.parse('2021-05-06 07:08:09'))
  end

  it 'forces utf-8 encoding on strings' do
    attrs = build(first_name: 'Ann'.dup.force_encoding('ASCII-8BIT'))

    expect(attrs[:first_name].encoding).to eq(Encoding::UTF_8)
  end
end

RSpec.describe ActiveRecordImporter::Attribute::FindOptionsBuilder do
  let(:attrs) { { first_name: 'Ann', last_name: nil, email: 'ann@example.com', ref_email: 'r@example.com' } }

  def build(options)
    described_class.new({ importable: User, attrs: attrs }.merge(options)).build
  end

  it 'slices the find options, dropping nil values' do
    expect(build(find_options: 'first_name, last_name,email')).to eq(first_name: 'Ann', email: 'ann@example.com')
  end

  it 'supports a prefix' do
    expect(build(find_options: 'email', prefix: 'ref_')).to eq(email: 'r@example.com')
  end
end
