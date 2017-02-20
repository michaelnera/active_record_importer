class ActiveRecordImporterMigration < ActiveRecord::Migration
  def change
    create_table :imports do |t|
      t.attachment  :file
      t.attachment  :failed_file
      t.text        :properties
      t.string      :resource,           null: false
      t.integer     :imported_rows,      default: 0
      t.integer     :failed_rows,        default: 0
      t.datetime    :updated_at
      t.datetime    :created_at
    end
  end
end
