##
# Database used by the spec suite.
#
#   DB=postgresql bundle exec rspec   (default)
#   DB=mysql      bundle exec rspec
#
# Connection settings can be overridden with the usual environment
# variables (see .configuration below).
##
module Database
  DATABASE = ENV.fetch('DB_NAME', 'active_record_importer_test')

  module_function

  def adapter
    ENV.fetch('DB', 'postgresql').to_s
  end

  def mysql?
    adapter == 'mysql'
  end

  def postgresql?
    adapter == 'postgresql'
  end

  def configuration
    if mysql?
      {
        adapter: ENV.fetch('MYSQL_ADAPTER', 'trilogy'),
        host: ENV.fetch('MYSQL_HOST', '127.0.0.1'),
        port: ENV.fetch('MYSQL_PORT', '3306').to_i,
        username: ENV.fetch('MYSQL_USER', 'root'),
        password: ENV.fetch('MYSQL_PASSWORD', ''),
        database: DATABASE
      }
    elsif postgresql?
      {
        adapter: 'postgresql',
        host: ENV['PG_HOST'],
        port: ENV['PG_PORT'],
        username: ENV['PG_USER'],
        password: ENV['PG_PASSWORD'],
        database: DATABASE
      }.compact
    else
      fail "Unsupported DB=#{adapter.inspect}, use postgresql or mysql"
    end
  end

  def connect!
    ActiveRecord::Base.establish_connection(configuration)
    ActiveRecord::Base.connection.execute('SELECT 1')
  rescue ActiveRecord::NoDatabaseError
    create_database!
    ActiveRecord::Base.establish_connection(configuration)
  end

  def create_database!
    admin_config = configuration.merge(database: postgresql? ? 'postgres' : nil).compact
    ActiveRecord::Base.establish_connection(admin_config)
    ActiveRecord::Base.connection.create_database(DATABASE)
  end

  def load_schema!
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string   :first_name
        t.string   :last_name
        t.string   :email
        t.string   :employee_no
        t.integer  :age
        t.string   :role
        t.string   :state
        t.string   :password
        t.text     :properties
        t.integer  :imports_count, default: 0
        t.timestamps null: true
      end
      add_index :users, :employee_no, unique: true

      create_table :imports, force: true do |t|
        t.text    :properties
        t.string  :resource, null: false
        t.integer :imported_rows, default: 0
        t.integer :failed_rows, default: 0
        t.text    :failed_file_content
        t.string  :failed_file_content_type
        t.timestamps null: true
      end
    end
  end

  def clean!
    %w(users imports).each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end
end
