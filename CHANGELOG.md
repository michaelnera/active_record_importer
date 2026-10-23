# Changelog

## 1.0.0

### Added
- Rows are persisted in bulk per CSV chunk through
  [activerecord-import](https://github.com/zdennis/activerecord-import):
  one bulk `INSERT` for new records and one bulk upsert (primary key conflict)
  for existing records, inside a single transaction per chunk.
- Existing records matched by `find_options` are loaded with a single query per chunk.
- Validations are kept: every row is validated (`valid?`) before persistence and invalid
  rows are written to the failed file with their errors, exactly as before.
- When the database rejects a bulk statement (e.g. a unique index without a model
  validation), the group is retried row by row in savepoints so only the offending rows fail.
- `acts_as_importable bulk_insert: false` saves rows one by one (still one transaction
  per chunk) so the model's own ActiveRecord save callbacks keep running.
- Spec suite running against PostgreSQL (default) and MySQL (`DB=mysql`).

### Changed
- **Bulk mode skips the model's own ActiveRecord save callbacks** (`before_save`,
  `after_create`, ...). Use `bulk_insert: false` if your model depends on them during import.
  Importer hooks (`before_save`, `after_save`, `state_machine_attr`) still run; when
  `after_save` or `state_machine_attr` are configured the chunk is saved row by row.
- Default `chunk_size` is now 500 (was `nil`, which processed one row at a time).
- `activerecord-import` is a new runtime dependency.
- RSpec 3 for development.

### Fixed
- Importer options were stored in a class variable shared by every importable model;
  each model now keeps its own options.
- `default_attributes` given as `Proc` or `Symbol` were never evaluated, and
  `importing: true` was not set on imported instances.
- `before_save`/`after_save` given as a single `Symbol` or `Proc` raised `NameError`.
- The failed file header row was not written as CSV.
- `File.exists?` (removed in Ruby 3.2) replaced with `File.exist?`.

## 0.4.0 and earlier

See the git history.
