require 'spec_helper'

RSpec.describe ActiveRecordImporter::RecordPreloader do
  subject(:preloader) { described_class.new(User) }

  let!(:ann) { User.create!(first_name: 'Ann', last_name: 'Lee', email: 'ann@example.com', employee_no: 'A', age: 30) }
  let!(:bob) { User.create!(first_name: 'Bob', last_name: 'Lee', email: 'bob@example.com', employee_no: 'B', age: 40) }

  describe '#preload' do
    it 'loads all matching records with a single query' do
      counts = count_queries do
        preloader.preload([{ email: 'ann@example.com' }, { email: 'bob@example.com' }, { email: 'nobody@example.com' }])
      end

      expect(counts['SELECT']).to eq(1)
      expect(count_queries { preloader.find(email: 'ann@example.com') }['SELECT']).to eq(0)
      expect(preloader.find(email: 'ann@example.com')).to eq(ann)
      expect(preloader.find(email: 'bob@example.com')).to eq(bob)
      expect(preloader.find(email: 'nobody@example.com')).to be_nil
    end

    it 'matches on every column for composite find options' do
      preloader.preload([{ first_name: 'Ann', last_name: 'Lee' }, { first_name: 'Bob', last_name: 'Smith' }])

      expect(preloader.find(first_name: 'Ann', last_name: 'Lee')).to eq(ann)
      expect(preloader.find(first_name: 'Bob', last_name: 'Smith')).to be_nil
    end

    it 'casts values with the column type' do
      preloader.preload([{ age: '30' }])

      expect(preloader.find(age: '30')).to eq(ann)
      expect(preloader.find(age: 30)).to eq(ann)
    end

    it 'ignores blank entries' do
      expect { preloader.preload([nil, {}]) }.not_to raise_error
    end
  end

  describe '#find' do
    it 'queries the database for a key that was not preloaded' do
      expect(preloader.find(email: 'bob@example.com')).to eq(bob)
    end

    it 'returns nil for blank attributes' do
      expect(preloader.find({})).to be_nil
    end
  end

  describe '#register' do
    it 'returns registered instances for subsequent lookups' do
      instance = User.new(email: 'new@example.com')

      expect(preloader.register({ email: 'new@example.com' }, instance)).to be(instance)
      expect(preloader.find(email: 'new@example.com')).to be(instance)
    end
  end
end
