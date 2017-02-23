# ActiveRecordImporter

Supports only Rails 4 and 5

This gem helps you insert/update records easily. For now, it only accepts CSV file.
This also helps you monitor how many rows are imported, and how many rows failed.
This gem also allows you to easily import to any model with few configurations.

I'll release an update to enable this on background job.

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
      t.timestamps
    end
  end
end
```

#### Import Model:
```ruby
class Import < ActiveRecord::Base
  extend Enumerize
  store :properties, accessors: %i(insert_method find_options batch_size)

  enumerize :insert_method,
            in: %w(insert upsert error_duplicate),
            default: :upsert

  has_attached_file :file

  attr_accessor :execute_on_create

  validates :resource, presence: true
  validate :check_presence_of_find_options
  validates_attachment :file,
                       content_type: {
                           content_type: %w(text/plain text/csv)
                       }

  after_create :execute, if: :execute_on_create

  # I'll add import options in the next release
  # accepts_nested_attributes_for :import_options, allow_destroy: true

  def execute
    resource_class.import!(self, execute_on_create)
  end

  def resource_class
    resource.safe_constantize
  end

  def batch_size
    super.to_i
  end

  ##
  # Override this if you prefer to have
  # a private permission or you have
  # private methods for reading files
  ##
  def import_file
    local_path? ? file.path : file.url
  end

  private

  def check_presence_of_find_options
    return if insert_method.insert?
    errors.add(:find_options, "can't be blank") if find_options.blank?
  end

  def local_path?
    File.exist? file.path
  end
end
```

Add `acts_as_importable` to a model to make it importable
```ruby
class User < ActiveRecord::Base
  acts_as_importable
end
```

You may also add import options:
```ruby
class User < ActiveRecord::Base
  acts_as_importable default_attributes: { first_name: 'Juan',
                                           last_name: 'dela Cruz' },
                     find_options: %i(email),
                     before_save: Proc.new { |user| user.password = 'temporarypassword123' }
end
```

#### Import Sample HAML Form
```ruby
    # resource is your Model name
    = f.input :resource
    # batch_size is useful for large csv file
    = f.input :batch_size
    # insert_methods: [:upsert, :insert, :error_on_duplicate]
    = f.input :insert_method, collection: insert_methods, class: 'form-control insert-method'
    # `find_options` are the list of columns you want to use to update a certain instance or
    # error when a duplicate is found. This is not required when your insert_method is `:insert`
    = f.input :find_options
    = f.input :file, as: :file,
      input_html: { accept: '.csv' }
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
    @import.execute_on_create = true
    @import.execute
  end

  private

  def import_params
    params.require(:import).permit(:file, :resource, :insert_method, :batch_size)
  end
end
```

You may include execute_on_create as a checkbox field in your Import form so you don't have to
include `@import.execute_on_create = true` in your controller.



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/michaelnera/active_record_importer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

