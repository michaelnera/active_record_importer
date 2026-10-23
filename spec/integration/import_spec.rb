require 'spec_helper'

RSpec.describe 'Importing a CSV file', type: :integration do
  let(:import) { Import.new(resource: 'User') }

  describe 'insert' do
    before { User.acts_as_importable }

    it 'inserts every valid row and records the counts' do
      run_import(User, user_rows(5), import: import)

      expect(User.count).to eq(5)
      expect(User.pluck(:email)).to match_array((1..5).map { |i| "user#{i}@example.com" })
      expect(import.imported_rows).to eq(5)
      expect(import.failed_rows).to eq(0)
      expect(import.failed_file_content).to be_nil
    end

    it 'persists a chunk with a single bulk INSERT' do
      counts = count_queries { run_import(User, user_rows(20)) }

      expect(User.count).to eq(20)
      expect(counts['INSERT']).to eq(1)
    end

    it 'works without an Import object and prints the errors of failed rows' do
      rows = user_rows(3)
      rows[1][:first_name] = ''

      expect { run_import(User, rows) }.to output(/First name can't be blank/).to_stdout
      expect(User.count).to eq(2)
    end

    it 'sets timestamps on the inserted records' do
      run_import(User, user_rows(2))

      expect(User.where(created_at: nil).count).to eq(0)
      expect(User.where(updated_at: nil).count).to eq(0)
    end

    it 'uses created_at/updated_at from the csv when present' do
      rows = user_rows(1, created_at: '2020-01-02 03:04:05', updated_at: '2020-02-03 04:05:06')
      run_import(User, rows)

      user = User.first
      expect(user.created_at.year).to eq(2020)
      expect(user.created_at.month).to eq(1)
      expect(user.updated_at.month).to eq(2)
    end

    it 'ignores csv columns that are not importable columns' do
      run_import(User, user_rows(1, id: 999, unknown_column: 'x'))

      expect(User.count).to eq(1)
      expect(User.first.id).not_to eq(999)
    end

    it 'skips the model save callbacks in bulk mode' do
      run_import(User, user_rows(2))

      expect(User.pluck(:imports_count)).to eq([0, 0])
    end
  end

  describe 'validations' do
    before { User.acts_as_importable }

    let(:rows) do
      [
        { first_name: 'Valid', email: 'valid@example.com', employee_no: 'A1', age: 30 },
        { first_name: '', email: 'noname@example.com', employee_no: 'A2', age: 30 },
        { first_name: 'Bad Email', email: 'not-an-email', employee_no: 'A3', age: 30 },
        { first_name: 'Bad Age', email: 'badage@example.com', employee_no: 'A4', age: -1 },
        { first_name: 'Also Valid', email: 'also@example.com', employee_no: 'A5', age: 31 }
      ]
    end

    it 'imports the valid rows and rejects the invalid ones' do
      run_import(User, rows, import: import)

      expect(User.pluck(:email)).to match_array(%w(valid@example.com also@example.com))
      expect(import.imported_rows).to eq(2)
      expect(import.failed_rows).to eq(3)
    end

    it 'writes the failed rows with their validation errors to the failed file' do
      run_import(User, rows, import: import)

      failed = import.failed_csv
      expect(import.failed_file_content_type).to eq('text/csv')
      expect(failed.headers).to include('first_name', 'email', 'import_errors')
      expect(failed.size).to eq(3)

      by_email = failed.map { |r| [r['email'], r['import_errors']] }.to_h
      expect(by_email['noname@example.com']).to eq("Validation failed: First name can't be blank")
      expect(by_email['not-an-email']).to eq('Validation failed: Email is invalid')
      expect(by_email['badage@example.com']).to eq('Validation failed: Age must be greater than 0')
    end

    it 'keeps the original row order in the failed file' do
      run_import(User, rows, import: import)

      expect(import.failed_csv.map { |r| r['email'] })
        .to eq(%w(noname@example.com not-an-email badage@example.com))
    end

    it 'still bulk inserts the valid rows' do
      counts = count_queries { run_import(User, rows) }

      expect(counts['INSERT']).to eq(1)
    end
  end

  describe 'database level errors' do
    before { User.acts_as_importable }

    it 'falls back to per-row saving so only the offending row fails' do
      User.create!(first_name: 'Existing', email: 'existing@example.com', employee_no: 'DUP')

      rows = user_rows(3)
      rows[1][:employee_no] = 'DUP' # violates the unique index, no model validation

      run_import(User, rows, import: import)

      expect(User.count).to eq(3)
      expect(User.pluck(:email)).to match_array(
        %w(existing@example.com user1@example.com user3@example.com)
      )
      expect(import.imported_rows).to eq(2)
      expect(import.failed_rows).to eq(1)

      failed = import.failed_csv
      expect(failed.size).to eq(1)
      expect(failed.first['email']).to eq('user2@example.com')
      expect(failed.first['import_errors']).to match(/DUP|unique|duplicate/i)
    end
  end

  describe 'upsert' do
    before do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(email)
    end

    let!(:existing) do
      User.create!(first_name: 'Old', last_name: 'Name', email: 'user1@example.com',
                   employee_no: 'OLD-1', age: 50)
    end

    it 'updates existing records and inserts the new ones' do
      run_import(User, user_rows(3), import: import)

      expect(User.count).to eq(3)
      existing.reload
      expect(existing.first_name).to eq('User1')
      expect(existing.employee_no).to eq('EMP-1')
      expect(existing.age).to eq(21)
      expect(import.imported_rows).to eq(3)
      expect(import.failed_rows).to eq(0)
    end

    it 'does not touch columns missing from the csv' do
      run_import(User, [{ email: 'user1@example.com', first_name: 'Renamed' }])

      existing.reload
      expect(existing.first_name).to eq('Renamed')
      expect(existing.last_name).to eq('Name')
      expect(existing.age).to eq(50)
    end

    it 'looks records up once per chunk and persists with one INSERT and one upsert' do
      User.create!(first_name: 'Another', email: 'user2@example.com', employee_no: 'OLD-2')

      counts = count_queries { run_import(User, user_rows(10)) }

      expect(counts['SELECT']).to eq(1)
      expect(counts['INSERT']).to eq(2)
      expect(counts['UPDATE'].to_i).to eq(0)
    end

    it 'validates updated records too' do
      run_import(User, [{ email: 'user1@example.com', age: -5 }], import: import)

      expect(existing.reload.age).to eq(50)
      expect(import.failed_rows).to eq(1)
      expect(import.failed_csv.first['import_errors'])
        .to eq('Validation failed: Age must be greater than 0')
    end

    it 'merges duplicate rows of the same chunk into one record' do
      rows = [
        { first_name: 'First', email: 'new@example.com', employee_no: 'N1' },
        { first_name: 'Second', email: 'new@example.com', employee_no: 'N1' }
      ]

      run_import(User, rows, import: import)

      created = User.where(email: 'new@example.com')
      expect(created.count).to eq(1)
      expect(created.first.first_name).to eq('Second')
      expect(import.imported_rows).to eq(2)
    end

    it 'supports multiple find options' do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(first_name last_name)
      doe = User.create!(first_name: 'User2', last_name: 'Doe', email: 'doe@example.com', employee_no: 'D')
      User.create!(first_name: 'User2', last_name: 'Smith', email: 'other@example.com', employee_no: 'X')

      run_import(User, user_rows(2))

      expect(User.count).to eq(4) # existing (Old Name), User1 Doe (new), User2 Doe (updated), User2 Smith
      expect(existing.reload.employee_no).to eq('OLD-1') # email is not part of the find options
      expect(doe.reload.email).to eq('user2@example.com')
      expect(User.find_by(first_name: 'User2', last_name: 'Smith').email).to eq('other@example.com')
    end

    it 'fails rows without find attributes' do
      run_import(User, [{ first_name: 'No Email', email: nil, employee_no: 'Z' }], import: import)

      expect(import.failed_rows).to eq(1)
      expect(import.failed_csv.first['import_errors'])
        .to eq('Find by option for your csv is missing or incorrect.')
    end

    it 'takes insert_method and find_options from the Import object' do
      User.acts_as_importable
      import.insert_method = 'upsert'
      import.find_options = 'email'

      run_import(User, user_rows(1), import: import)

      expect(User.count).to eq(1)
      expect(existing.reload.first_name).to eq('User1')
    end
  end

  describe 'error_duplicate' do
    before do
      User.acts_as_importable insert_method: 'error_duplicate', find_options: %i(email)
      User.create!(first_name: 'Old', email: 'user1@example.com', employee_no: 'OLD-1')
    end

    it 'rejects rows matching an existing record' do
      run_import(User, user_rows(3), import: import)

      expect(User.count).to eq(3)
      expect(User.find_by(email: 'user1@example.com').first_name).to eq('Old')
      expect(import.imported_rows).to eq(2)
      expect(import.failed_rows).to eq(1)
      expect(import.failed_csv.first['import_errors']).to eq('Duplicate record found!')
    end

    it 'rejects duplicates within the same chunk' do
      rows = user_rows(2, email: 'same@example.com')
      rows[1][:employee_no] = 'OTHER'

      run_import(User, rows, import: import)

      expect(User.where(email: 'same@example.com').count).to eq(1)
      expect(import.imported_rows).to eq(1)
      expect(import.failed_rows).to eq(1)
    end
  end

  describe 'importer options' do
    it 'applies default_attributes (values, procs and symbols)' do
      User.acts_as_importable default_attributes: {
        last_name: 'Default',
        password: proc { |row| "pw-#{row[:first_name]}" },
        role: :member_role
      }

      run_import(User, [{ first_name: 'Ann', email: 'ann@example.com', employee_no: 'A' }])

      user = User.first
      expect(user.last_name).to eq('Default')
      expect(user.password).to eq('pw-Ann')
      expect(user.role).to eq('member')
    end

    it 'lets csv values override default_attributes' do
      User.acts_as_importable default_attributes: { last_name: 'Default' }

      run_import(User, user_rows(1))

      expect(User.first.last_name).to eq('Doe')
    end

    it 'imports store accessors' do
      User.acts_as_importable store_accessors: %i(nickname department)

      run_import(User, user_rows(1, nickname: 'annie', department: 'R&D'))

      expect(User.first.nickname).to eq('annie')
      expect(User.first.department).to eq('R&D')
    end

    it 'excludes columns listed in exclude_columns' do
      User.acts_as_importable exclude_columns: %i(age)

      run_import(User, user_rows(1))

      expect(User.first.age).to be_nil
    end

    it 'runs before_save procs before validating' do
      User.acts_as_importable before_save: proc { |user| user.password = 'temporary123' }

      run_import(User, user_rows(2))

      expect(User.pluck(:password).uniq).to eq(['temporary123'])
    end

    it 'keeps options separate per model' do
      User.acts_as_importable

      expect(User.importer_options.insert_method).to be_nil
      expect(Account.importer_options.insert_method).to eq('upsert')
      expect(Account.importer_options.find_options).to eq([:email])
    end

    it 'honours csv_opts' do
      User.acts_as_importable csv_opts: { col_sep: '|' }
      path = csv_file(user_rows(1))
      File.write(path, "first_name|email|employee_no\nPipe|pipe@example.com|P1\n")

      User.import!(file: path)

      expect(User.first.first_name).to eq('Pipe')
    end
  end

  describe 'per-row fallback' do
    it 'runs after_save hooks on persisted instances' do
      User.acts_as_importable after_save: proc { |user| User.after_save_log << user.id }

      run_import(User, user_rows(3), import: import)

      expect(User.after_save_log.sort).to eq(User.pluck(:id).sort)
      expect(import.imported_rows).to eq(3)
    end

    it 'accepts symbol and array after_save hooks' do
      User.acts_as_importable after_save: [:activate]

      run_import(User, user_rows(2))

      expect(User.pluck(:state).uniq).to eq(['active'])
    end

    it 'applies state machine transitions after saving' do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(email),
                              state_machine_attr: %i(state)
      pending = User.create!(first_name: 'P', email: 'user1@example.com', employee_no: 'P1', state: 'pending')

      run_import(User, user_rows(1, state: 'active'), import: import)

      expect(pending.reload.state).to eq('active')
      expect(User.state_log).to eq([[pending.id, 'active']])
      expect(import.imported_rows).to eq(1)
    end

    it 'fails the row when the transition is invalid' do
      User.acts_as_importable insert_method: 'upsert', find_options: %i(email),
                              state_machine_attr: %i(state)
      pending = User.create!(first_name: 'P', email: 'user1@example.com', employee_no: 'P1', state: 'pending')

      run_import(User, user_rows(1, state: 'archived'), import: import)

      expect(pending.reload.state).to eq('pending')
      expect(pending.first_name).to eq('P') # rolled back
      expect(import.failed_rows).to eq(1)
      expect(import.failed_csv.first['import_errors']).to eq('Transition is invalid')
    end

    it 'runs the model callbacks when bulk_insert is disabled' do
      User.acts_as_importable bulk_insert: false

      counts = count_queries { run_import(User, user_rows(3), import: import) }

      expect(User.pluck(:imports_count)).to eq([1, 1, 1])
      expect(counts['INSERT']).to eq(3)
      expect(import.imported_rows).to eq(3)
    end

    it 'still reports validation errors' do
      User.acts_as_importable bulk_insert: false
      rows = user_rows(2)
      rows[0][:email] = 'broken'

      run_import(User, rows, import: import)

      expect(User.count).to eq(1)
      expect(import.failed_rows).to eq(1)
      expect(import.failed_csv.first['import_errors']).to eq('Validation failed: Email is invalid')
    end
  end

  describe 'batching' do
    before { User.acts_as_importable }

    it 'splits the file in chunks of batch_size' do
      import.batch_size = 4

      counts = count_queries { run_import(User, user_rows(10), import: import) }

      expect(User.count).to eq(10)
      expect(counts['INSERT']).to eq(3)
      expect(import.imported_rows).to eq(10)
    end

    it 'accumulates counters across chunks' do
      import.batch_size = 2
      rows = user_rows(5)
      rows[0][:first_name] = ''
      rows[4][:first_name] = ''

      run_import(User, rows, import: import)

      expect(import.imported_rows).to eq(3)
      expect(import.failed_rows).to eq(2)
      expect(import.failed_csv.size).to eq(2)
    end

    it 'uses the chunk_size from csv_opts when the import has no batch_size' do
      User.acts_as_importable csv_opts: { chunk_size: 5 }

      counts = count_queries { run_import(User, user_rows(10)) }

      expect(counts['INSERT']).to eq(2)
    end
  end

  describe 'Import#execute!' do
    before { User.acts_as_importable }

    it 'runs the import for the resource' do
      import.file = File.new(csv_file(user_rows(2)))
      import.save!

      import.execute!

      expect(User.count).to eq(2)
      expect(import.reload.imported_rows).to eq(2)
    end
  end

  describe 'errors' do
    it 'refuses to import a model without acts_as_importable' do
      expect { Plain.import!(file: 'whatever.csv') }.to raise_error(/Plain is not importable/)
    end

    it 'requires a file' do
      User.acts_as_importable
      expect { User.import! }.to raise_error(ActiveRecordImporter::Errors::MissingImportFile)
    end
  end
end
