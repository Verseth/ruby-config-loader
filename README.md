# ConfigFileManager

This gem makes it easier to manage your configuration files in Ruby apps.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add config_file_manager

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install config_file_manager

## Usage

This gem adds a new class `ConfigFileManager`, which helps you load and list config files and config directories.

The basic idea is that config files with sensitive information should
not be stored in git (they are often added to `.gitignore`).
This gem expects that you create dummy/example versions of config files
that are checked into git.

For example let's say that you've got a config file `foo.yml`. This file should be added to gitignore and you should create a dummy version called `foo.yml.example` that will be stored in git.

```
config/
├─ foo.yml          -- in .gitignore
└─ foo.yml.example
```

You can choose the suffix of the dummy file for example `foo.yml.dummy`.

### with capistrano

You can use this gem to easily configure automatic symlinking of config files in `capistrano`.

```rb
# config/deploy.rb

# path to the repo root
root_path = File.expand_path('..', __dir__)
# path to the `config/` directory
config_dir_path = File.expand_path(__dir__)

config_file_manager = ConfigFileManager.new(config_dir_path)
# get absolute paths to all config files and change them
# to relative paths (relative to the repo root)
linked_files = config_file_manager.files.map { _1.delete_prefix("#{root_path}/") }
set :linked_files, linked_files
```

That way you don't have to specify the config files by hand.

### with Rails

This gem can greatly reduce boilerplate in Rails initializers that load config files.

Create an initializer that will be executed first and creates a configured instance of `ConfigFileManager` and saves it to a constant so it can be accessed in other initializers.

```rb
# config/initializers/0_config_file_manager.rb

CONFIG_MANAGER = ConfigFileManager.new(File.expand_path('..', __dir__), env: Rails.env)
```

And then you can you it to conveniently load config files.

```rb
# config/initializers/foo.rb

FOO = CONFIG_MANAGER.load_yaml('foo.yml')
```

### ConfigFileManager initializer

To start managing your config file you should create a new `ConfigFileManager`.

```rb
require 'config_file_manager'

loader = ConfigFileManager.new(File.expand_path('config', __dir__))
```

The loader has one required argument `config_dir`, an absolute path
to the directory that contains your config files.

You can also specify a custom dummy file extension (by default it is `.example`).

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__), example_extension: '.dummy')
```

In this case the gem would expect something like this:

```
config/
├─ foo.yml          -- in .gitignore
└─ foo.yml.dummy
```

You can also specify the current environment.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__), env: 'production')
```

### files

This method let's you list all required config files (based on the dummy files).
Let's say that you've got a directory like this.

```
config/
├─ foo.yml.example
├─ bar.txt.example
├─ bar.txt
└─ subdir/
   └─ baz.yml.example
```

Then you could retrieve the absolute paths to all required config files (no matter if they exist or not).

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.files
# => ["/Users/Verseth/my_app/config/foo.yml", "/Users/Verseth/my_app/config/bar.txt", "/Users/Verseth/my_app/config/subdir/baz.yml"]
```

### missing_files

This method let's you list all missing config files (based on the dummy files).
Let's say that you've got a directory like this.

```
config/
├─ foo.yml.example
├─ bar.txt.example
├─ bar.txt
└─ subdir/
   └─ baz.yml.example
```

Then you could retrieve the absolute paths to all missing config files (dummy files with no real versions).

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.missing_files
# => ["/Users/Verseth/my_app/config/foo.yml", "/Users/Verseth/my_app/config/subdir/baz.yml"]
```

### create_missing_files

This method let's you create all missing config files (by copying the dummy files).

Let's say that you've got a directory like this.

```
config/
├─ foo.yml.example
├─ bar.txt.example
├─ bar.txt
└─ subdir/
   └─ baz.yml.example
```

Then you could create the missing files like so.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.create_missing_files(print: true)
# == Copying missing config files ==
#        copy  /Users/Verseth/my_app/config/foo.yml.example
#        copy  /Users/Verseth/my_app/config/subdir/baz.yml.example
```

By default no output is printed. To turn it on you must call the method
with `print: true`.

### to_relative_path

Converts an absolute path within the config directory to a relative path.

You can use it like so.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.to_relative_path("/Users/Verseth/my_app/config/foo.yml")
#=> "foo.yml"
```

### to_absolute_path

Converts an absolute path within the config directory to a relative path.

You can use it like so.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.to_absolute_path("foo.yml")
#=> "/Users/Verseth/my_app/config/foo.yml"
```

### load_yaml

Let's you load the content of a YAML file with ERB.
Keys are symbolized by default. The default environment is `"development"`.

Let's say that you've got a config file like this.
```yaml
# config/foo.yml
development:
    foo: dev value <%= 2 + 5 %>

production:
    foo: prod value <%= 10 - 2 %>
```

You can load it like so.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.load_yaml('foo.yml')
#=> { foo: "dev value 7" }
```

You can also load a section for another environment by altering the constructor.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__), env: 'production')
loader.load_yaml('foo.yml')
#=> { foo: "prod value 8" }
```

Or by passing another argument to the method.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.load_yaml('foo.yml', env: 'production')
#=> { foo: "prod value 8" }
```

You can also disable key symbolization.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.load_yaml('foo.yml', symbolize: false)
#=> { "foo" => "dev value 7" }
```

Or load the entire content of the file without looking at a specific environment.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.load_yaml('foo.yml', env: nil)
#=> { development: { foo: "dev value 7" }, production: { foo: "prod value 8" } }
```

### load_erb

Preprocesses the content of a file with ERB and returns a Ruby `String` with it.

Let's say that you've got a config file like this in `config/foo.txt`

```
This is a file with ERB: <%= 2 - 3 %>
```

You can load it like so.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.load_erb('foo.txt')
# => "This is a file with ERB: -1"
```

### load_file

Load the content of the file to a Ruby `String`.

Let's say that you've got a config file like this in `config/foo.txt`

```
This is a file!
```

You can load it like so.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.load_file('foo.txt')
# => "This is a file!"
```

### file_exist?

Check whether a file exists under the config directory.

Let's say that you've got a directory like this.

```
config/
├─ foo.yml.example
├─ bar.txt.example
├─ bar.txt
└─ subdir/
   └─ baz.yml.example
```

You can perform the following checks.

```rb
loader = ConfigFileManager.new(File.expand_path('config', __dir__))
loader.file_exist?('foo.yml.example') #=> true
loader.file_exist?('bar.yml') #=> false
loader.file_exist?('subdir/baz.yml.example') #=> true
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Verseth/ruby-config-loader.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
