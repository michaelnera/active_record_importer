require 'tempfile'
require 'csv'

module CsvHelper
  ##
  # Writes rows (array of hashes sharing the same keys) to a temp csv
  # and returns its path. The file lives for the duration of the example.
  ##
  def csv_file(rows, headers: nil)
    headers ||= rows.first.keys
    file = Tempfile.new(['import', '.csv'])
    file.write(CSV.generate_line(headers))
    rows.each { |row| file.write(CSV.generate_line(headers.map { |h| row[h] })) }
    file.flush
    (@csv_files ||= []) << file
    file.path
  end

  def user_rows(count, overrides = {})
    (1..count).map do |i|
      {
        first_name: "User#{i}",
        last_name: 'Doe',
        email: "user#{i}@example.com",
        employee_no: "EMP-#{i}",
        age: 20 + i
      }.merge(overrides)
    end
  end

  def run_import(klass, rows, import: nil, headers: nil)
    path = csv_file(rows, headers: headers)
    if import
      import.file = File.new(path)
      import.save!
      klass.import!(object: import)
      import.reload
    else
      klass.import!(file: path)
    end
  end
end
