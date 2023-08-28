# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require 'erb'
require 'pastel'

require_relative 'config_loader/version'

# Class that let's you manage your configuration files.
class ConfigLoader
  COLORS = ::Pastel.new

  # Absolute path to the main directory that contains all config files (and subdirectories).
  #
  # @return [String]
  attr_reader :config_dir

  # Maximum depth of nested directories containing config files.
  #
  # @return [Integer]
  attr_reader :max_dir_depth

  # Current environment name. Used to load the correct section of YAML files.
  #
  # @return [String]
  attr_reader :env

  # Extension of the example/dummy version of a config file.
  # eg. `.example`, `.dummy`
  #
  # @return [String]
  attr_reader :example_extension

  # @param config_dir [String] Absolute path to the root config directory
  # @param example_extension [String]
  # @param max_dir_depth [Integer] Maximum depth of nested directories containing config files.
  # @param env [String] Current environment name
  def initialize(config_dir, example_extension: '.example', max_dir_depth: 5, env: 'development')
    @config_dir = config_dir
    @example_extension = example_extension
    @max_dir_depth = max_dir_depth
    @env = env
  end

  # Recursively search for files under the `config_dir` directory
  # with the specified extension (eg. `.example`).
  # Returns an array of absolute paths to the found files
  # with the specified extension stripped away.
  #
  # @param example_extension [String] File extension of example files
  # @return [Array<String>]
  def files(example_extension: @example_extension, result: [], depth: 0, dir_path: @config_dir)
    return result if depth > @max_dir_depth

    ::Dir.each_child(dir_path) do |path|
      abs_path = ::File.join(dir_path, path)

      if ::File.directory?(abs_path)
        # if the entry is a directory, scan it recursively
        # this essentially performs a depth limited search (DFS with a depth limit)
        next files(
          example_extension: example_extension,
          result: result,
          depth: depth + 1,
          dir_path: abs_path
        )
      end

      next unless ::File.file?(abs_path) && path.end_with?(example_extension)

      result << abs_path.delete_suffix(example_extension)
    end

    result
  end

  # @param example_extension [String]
  # @return [Array<String>] Absolute paths to missing config files.
  def missing_files(example_extension: @example_extension)
    files(example_extension: example_extension).reject do |file|
      ::File.exist?(file)
    end
  end

  # Create the missing config files based on their dummy/example versions.
  #
  # @param example_extension [String]
  # @param print [Boolean]
  # @return [void]
  def create_missing_files(example_extension: @example_extension, print: false)
    puts COLORS.blue('== Copying missing config files ==') if print
    files(example_extension: example_extension).each do |file|
      create_missing_file("#{file}#{example_extension}", file, print: print)
    end
  end

  # Search for directories under the `config_dir` directory
  # with the specified ending (eg. `.example`).
  # Returns an array of absolute paths to the found files
  # with the specified ending stripped away.
  #
  # @param example_extension [String] ending of example directories
  # @return [Array<String>]
  def dirs(example_extension: @example_extension)
    ::Dir.each_child(@config_dir)
         .map { ::File.join(@config_dir, _1) }
         .select { ::File.directory?(_1) && _1.end_with?(example_extension) }
         .map { _1.delete_suffix(example_extension) }
  end

  # @param example_extension [String]
  # @return [Array<String>] Absolute paths to missing config directories.
  def missing_dirs(example_extension: @example_extension)
    dirs(example_extension: example_extension).reject do |file|
      ::Dir.exist?(file)
    end
  end

  # Create the missing config directories based on their dummy/example versions.
  #
  # @param example_extension [String]
  # @param print [Boolean]
  # @return [void]
  def create_missing_dirs(example_extension: @example_extension, print: false)
    puts COLORS.blue('== Copying missing config directories ==') if print
    dirs(example_extension: example_extension).each do |dir|
      create_missing_dir("#{dir}#{example_extension}", file, print: print)
    end
  end

  # Converts a collection of absolute paths to an array of
  # relative paths.
  #
  # @param absolute_paths [Array<String>]
  # @return [Array<String>]
  def to_relative_paths(absolute_paths)
    absolute_paths.map do |path|
      to_relative_path(path)
    end
  end

  # Converts an absolute path to a relative path
  #
  # @param absolute_path [String]
  # @return [String]
  def to_relative_path(absolute_path)
    absolute_path.delete_prefix("#{@config_dir}/")
  end

  # Converts a collection of relative paths to an array of
  # absolute paths.
  #
  # @param relative_paths [Array<String>]
  # @return [Array<String>]
  def to_absolute_paths(relative_paths)
    relative_paths.map do |path|
      to_absolute_path(path)
    end
  end

  # Converts a relative path to an absolute path.
  #
  # @param relative_path [String]
  # @return [String]
  def to_absolute_path(relative_path)
    "#{@config_dir}/#{relative_path}"
  end

  # @param file_name [Array<String>]
  # @param env [String, nil]
  # @param symbolize [Boolean] Whether the keys should be converted to Ruby symbols
  # @return [Hash, Array]
  def load_yaml(*file_name, env: @env, symbolize: true)
    env = env.to_sym if env && symbolize
    parsed = ::YAML.load(load_erb(*file_name), symbolize_names: symbolize) # rubocop:disable Security/YAMLLoad
    return parsed unless env

    parsed[env]
  end

  # @param file_name [Array<String>]
  def delete_file(*file_name)
    ::File.delete(file_path(*file_name))
  end

  # @param file_name [Array<String>]
  # @return [String]
  def load_erb(*file_name)
    ::ERB.new(load_file(*file_name)).result
  end

  # @param file_name [Array<String>]
  # @return [String]
  # @raise [SystemCallError]
  def load_file(*file_name)
    ::File.read file_path(*file_name)
  end

  # @param file_name [Array<String>]
  # @return [Boolean]
  def file_exist?(*file_name)
    ::File.exist? file_path(*file_name)
  end

  # @param dir_name [Array<String>]
  # @return [Boolean]
  def dir_exist?(*dir_name)
    ::Dir.exist? file_path(*dir_name)
  end

  # @param file_name [Array<String>]
  # @return [String]
  def file_path(*file_name)
    *path, name = file_name
    ::File.join(@config_dir, *path, name)
  end

  private

  # @param original_name [String]
  # @param new_name [String]
  # @param print [Boolean]
  # @return [Boolean]
  def create_missing_file(original_name, new_name, print: false)
    return false if ::File.exist?(new_name)

    ::FileUtils.cp original_name, new_name
    if print
      copy = COLORS.green.bold 'copy'.rjust(12, ' ')
      puts "#{copy}  #{original_name}"
    end

    true
  end

  # @param original_name [String]
  # @param new_name [String]
  # @param print [Boolean]
  # @return [Boolean]
  def create_missing_dir(original_name, new_name, print: false)
    return false if ::Dir.exist?(new_name)

    ::FileUtils.cp_r original_name, new_name
    if print
      copy = COLORS.green.bold 'copy'.rjust(12, ' ')
      puts "#{copy}  #{original_name}"
    end

    true
  end
end
