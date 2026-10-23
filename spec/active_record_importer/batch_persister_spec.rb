require 'spec_helper'

RSpec.describe ActiveRecordImporter::BatchPersister do
  before { User.acts_as_importable }

  def processor_for(attrs)
    ActiveRecordImporter::DataProcessor.new(importable: User, row_attrs: attrs).tap(&:process)
  end

  let(:rows) { user_rows(3) }
  let(:processors) { rows.map { |row| processor_for(row) } }

  subject(:persister) { described_class.new(importable: User, processors: processors) }

  it 'does nothing without processors' do
    expect { described_class.new(importable: User).persist! }.not_to change(User, :count)
  end

  it 'inserts new instances in bulk' do
    counts = count_queries { persister.persist! }

    expect(User.count).to eq(3)
    expect(counts['INSERT']).to eq(1)
    expect(processors.none?(&:failed?)).to be(true)
  end

  it 'marks the offending row as failed when a database error occurs' do
    User.create!(first_name: 'Dup', email: 'dup@example.com', employee_no: 'EMP-2')

    persister.persist!

    expect(User.count).to eq(3)
    expect(processors.map(&:failed?)).to eq([false, true, false])
    expect(processors[1].row_errors).to be_present
  end

  it 'updates existing instances in bulk' do
    User.acts_as_importable insert_method: 'upsert', find_options: %i(email)
    first = User.create!(first_name: 'Old', email: 'user1@example.com', employee_no: 'X1')
    second = User.create!(first_name: 'Old', email: 'user2@example.com', employee_no: 'X2')

    counts = count_queries { persister.persist! }

    expect(counts['INSERT']).to eq(2) # one for the new row, one upsert for the existing rows
    expect(first.reload.first_name).to eq('User1')
    expect(second.reload.first_name).to eq('User2')
    expect(User.count).to eq(3)
  end

  it 'skips the update statement when nothing changed' do
    User.acts_as_importable insert_method: 'upsert', find_options: %i(email)
    User.create!(first_name: 'Same', email: 'same@example.com')
    processor = ActiveRecordImporter::DataProcessor.new(
      importable: User, row_attrs: { email: 'same@example.com' }
    )
    processor.process
    processor.instance.updated_at = processor.instance.updated_at_was
    processor.instance.created_at = processor.instance.created_at_was

    counts = count_queries { described_class.new(importable: User, processors: [processor]).persist! }

    expect(counts['INSERT'].to_i).to eq(0)
    expect(processor.failed?).to be(false)
  end

  context 'when importer callbacks need a persisted instance' do
    before { User.acts_as_importable after_save: proc { |u| User.after_save_log << u.id } }

    it 'saves rows one by one and runs the callbacks' do
      counts = count_queries { persister.persist! }

      expect(counts['INSERT']).to eq(3)
      expect(User.after_save_log.size).to eq(3)
    end
  end

  context 'when bulk_insert is disabled' do
    before { User.acts_as_importable bulk_insert: false }

    it 'saves rows one by one' do
      counts = count_queries { persister.persist! }

      expect(counts['INSERT']).to eq(3)
      expect(User.pluck(:imports_count).uniq).to eq([1])
    end
  end
end
