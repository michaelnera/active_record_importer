require 'spec_helper'

RSpec.describe ActiveRecordImporter::DataProcessor do
  before { User.acts_as_importable }

  def processor(row_attrs, options = {})
    described_class.new({ importable: User, row_attrs: row_attrs }.merge(options))
  end

  describe '#process' do
    it 'builds a valid, unsaved instance' do
      subject = processor(first_name: 'Ann', email: 'ann@example.com')

      expect(subject.process).to be(true)
      expect(subject.instance).to be_new_record
      expect(subject.instance.first_name).to eq('Ann')
      expect(subject.instance.importing?).to be(true)
      expect(subject).to be_ready
    end

    it 'records validation errors without raising' do
      subject = processor(first_name: '', email: 'ann@example.com')

      expect(subject.process).to be(false)
      expect(subject).to be_failed
      expect(subject.row_errors).to eq("Validation failed: First name can't be blank")
    end

    it 'records errors raised while building attributes' do
      User.acts_as_importable default_attributes: { role: proc { fail 'boom' } }
      subject = processor(first_name: 'Ann', email: 'ann@example.com')

      expect(subject.process).to be(false)
      expect(subject.row_errors).to eq('boom')
      expect(subject.instance).to be_nil
    end
  end

  describe 'insert method and find options' do
    it 'defaults to insert' do
      expect(processor({}).insert_method).to eq('insert')
      expect(processor({}).find_attributes_for_lookup).to be_nil
    end

    it 'prefers the Import object settings over the importer options' do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(email)
      import = Import.new(resource: 'User', insert_method: 'error_duplicate', find_options: 'first_name')
      subject = processor({ first_name: 'Ann', email: 'ann@example.com' }, import: import)
      subject.prepare

      expect(subject.insert_method).to eq('error_duplicate')
      expect(subject.find_attributes_for_lookup).to eq(first_name: 'Ann')
    end

    it 'uses the importer options when there is no Import object' do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(email first_name)
      subject = processor(first_name: 'Ann', email: 'ann@example.com')
      subject.prepare

      expect(subject.insert_method).to eq('upsert')
      expect(subject.find_attributes).to eq(email: 'ann@example.com', first_name: 'Ann')
    end
  end

  describe '#after_persist' do
    it 'runs state transitions and after_save hooks on persisted instances' do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(email),
                              state_machine_attr: %i(state),
                              after_save: proc { |u| User.after_save_log << u.id }
      user = User.create!(first_name: 'Ann', email: 'ann@example.com', state: 'pending')
      subject = processor(email: 'ann@example.com', state: 'active')
      subject.process
      subject.instance.save!

      subject.after_persist

      expect(user.reload.state).to eq('active')
      expect(User.after_save_log).to eq([user.id])
    end

    it 'does not assign state machine attributes directly' do
      User.acts_as_importable state_machine_attr: %i(state)
      subject = processor(first_name: 'Ann', email: 'ann@example.com', state: 'active')
      subject.process

      expect(subject.instance.state).to be_nil
    end
  end
end
