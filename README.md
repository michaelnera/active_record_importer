# ActiveRecordImporter

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/active_record_importer`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record_importer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_record_importer

## Usage

Simple usage for now:

### Create Import table/model
I'll add a generator on my next release
#### DB Migration:
```ruby
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
```

#### Import Model:
```ruby
class Import < ActiveRecord::Base
  store :properties, accessors: %i(insert_method find_options batch_size)

  enumerize :insert_method,
            in: %w(insert upsert error_duplicate),
            default: :upsert

  has_attached_file :file

  attr_accessor :execute_on_create

  validate :check_presence_of_find_options
  validates_attachment :file,
                       content_type: {
                           content_type: %w(text/plain text/csv)
                       }

  accepts_nested_attributes_for :import_options, allow_destroy: true

  def import!
    ActiveRecordImporter::Dispatcher.new(
      self.id, execute_on_create
    ).call
  end

  def batch_size
    super.to_i
  end

  private

  def check_presence_of_find_options
    return if insert_method.insert?
    errors.add(:find_options, "can't be blank") if find_options.blank?
  end

  ##
  # Override this if you prefer have
  # a private permissions or you have
  # private methods for reading files
  ##
  def import_file
    local_path? ? file.path : file.url
  end

  private

  def local_path?
    File.exist? import_file.file.path
  end
end
```

### Rails 4:
```ruby
class User < ActiveRecord::Base
  acts_as_importable
end
```

### Rails 5:
```ruby
class User < ApplicationRecord
  acts_as_importable
end
```

You may also add import options:
```ruby
acts_as_importable default_attributes: { first_name: 'Juan',
                                         last_name: 'dela Cruz' },
                   find_options: %i(email),
                   before_save: Proc.new { |user| user.password = 'temporarypassword123' }
```

You may also add some options from the SmarterCSV gem:

    | Option                         |  Default
    --------------------------------------------------------------
    | :convert_values_to_metric      |  nil
    | :value_converters              |  nil
    | :remove_empty_values           |  false
    | :comment_regexp                |  Regexp.new(/^#=>/)
    | :force_utf8                    |  true
    | :chunk_size                    |  500
    | :col_sep                       |  ","

#### I'll add more options SOON!

#### Imports Controller:
```ruby
class ImportsController < ApplicationController

  def create
    @import = Import.create!(import_params)
    @import.import!
  end

end
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/michaelnera/active_record_importer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

