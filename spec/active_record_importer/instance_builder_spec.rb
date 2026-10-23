require 'spec_helper'

RSpec.describe ActiveRecordImporter::InstanceBuilder do
  before { User.acts_as_importable }

  let(:lookup) { ActiveRecordImporter::RecordPreloader.new(User) }

  def build(options = {})
    described_class.new({ importable: User, lookup: lookup }.merge(options)).build
  end

  it 'builds a new validated instance for insert' do
    instance = build(instance_attrs: { first_name: 'Ann', email: 'ann@example.com' })

    expect(instance).to be_new_record
    expect(instance).to be_valid
  end

  it 'raises RecordInvalid for invalid instances' do
    expect { build(instance_attrs: { first_name: 'Ann', email: 'nope' }) }
      .to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Email is invalid')
  end

  it 'runs the before_save callback before assigning attributes' do
    User.acts_as_importable before_save: proc { |user| user.last_name = 'Callback' }

    instance = build(instance_attrs: { first_name: 'Ann', email: 'ann@example.com' })

    expect(instance.last_name).to eq('Callback')
  end

  context 'upsert' do
    let!(:ann) { User.create!(first_name: 'Ann', email: 'ann@example.com') }

    it 'returns the existing record with the new attributes' do
      instance = build(insert_method: 'upsert',
                       find_attributes: { email: 'ann@example.com' },
                       instance_attrs: { first_name: 'Annie' })

      expect(instance).to eq(ann)
      expect(instance.first_name).to eq('Annie')
      expect(instance).to be_changed
    end

    it 'initializes and registers a new record when none matches' do
      instance = build(insert_method: 'upsert',
                       find_attributes: { email: 'new@example.com' },
                       instance_attrs: { first_name: 'New', email: 'new@example.com' })

      expect(instance).to be_new_record
      expect(lookup.find(email: 'new@example.com')).to be(instance)
    end

    it 'requires find attributes' do
      expect { build(insert_method: 'upsert', find_attributes: {}) }
        .to raise_error(ActiveRecordImporter::Errors::MissingFindByOption)
    end
  end

  context 'error_duplicate' do
    it 'raises when the record exists' do
      User.create!(first_name: 'Ann', email: 'ann@example.com')

      expect do
        build(insert_method: 'error_duplicate', find_attributes: { email: 'ann@example.com' })
      end.to raise_error(ActiveRecordImporter::Errors::DuplicateRecord)
    end

    it 'raises when the record was registered earlier in the chunk' do
      lookup.register({ email: 'ann@example.com' }, User.new)

      expect do
        build(insert_method: 'error_duplicate', find_attributes: { email: 'ann@example.com' })
      end.to raise_error(ActiveRecordImporter::Errors::DuplicateRecord)
    end
  end
end
