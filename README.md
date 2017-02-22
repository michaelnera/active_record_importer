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

    Option                        |  Default
    convert_values_to_metric      |  nil
    value_converters              |  nil
    remove_empty_values           |  false
    comment_regexp                |  Regexp.new(/^#=>/)
    force_utf8                    |  true
    chunk_size                    |  500
    col_sep                       |  ","

I'll add more options SOON!


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/michaelnera/active_record_importer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

