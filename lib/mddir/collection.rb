# frozen_string_literal: true

require "yaml"
require "fileutils"

module Mddir
  class Collection
    attr_reader :name, :config, :path

    def initialize(name, config)
      @name = Utils.slugify(name)
      @config = config
      @path = File.join(config.base_dir, @name)
    end

    def self.all(config)
      base = config.base_dir
      return [] unless Dir.exist?(base)

      Dir.children(base)
         .select { |child| File.directory?(File.join(base, child)) }
         .sort
         .map { |folder| new(folder, config) }
    end

    def exist?
      Dir.exist?(@path)
    end

    def entries
      load_index
    end

    def entry_count
      entries.length
    end

    def last_added
      entries_list = entries
      return nil if entries_list.empty?

      entries_list.map { |entry| entry["saved_at"] }.compact.max
    end

    def find_entry(identifier)
      entries_list = entries

      if identifier.match?(/\A\d+\z/)
        index = identifier.to_i - 1
        entries_list[index] if index >= 0 && index < entries_list.length
      else
        slug = identifier.delete_suffix(".md")
        entries_list.find { |entry| entry["slug"] == slug }
      end
    end

    def index_path
      File.join(@path, "index.yml")
    end

    def create!
      FileUtils.mkdir_p(@path)
      write_index([]) unless File.exist?(index_path)
      GlobalIndex.update!(config)
      self
    end

    def add_entry(entry_data) # rubocop:disable Naming/PredicateMethod
      entries_list = entries
      return false if entries_list.any? { |entry| entry["url"] == entry_data["url"] }

      entries_list << entry_data
      write_index(entries_list)
      GlobalIndex.update!(config)
      true
    end

    def remove_entry(identifier)
      entry = find_entry(identifier)
      return nil unless entry

      file_path = File.join(@path, entry["filename"])
      FileUtils.rm_f(file_path)

      entries_list = entries.reject { |list_entry| list_entry["filename"] == entry["filename"] }
      write_index(entries_list)
      GlobalIndex.update!(config)
      entry
    end

    def remove!
      FileUtils.rm_rf(@path)
      GlobalIndex.update!(config)
      SearchIndex.open(config) { |index| index.remove_collection!(name) }
    end

    private

    def load_index
      return [] unless File.exist?(index_path)

      data = YAML.safe_load_file(index_path, permitted_classes: [Time])
      data.is_a?(Array) ? data : []
    rescue Psych::SyntaxError
      warn "Warning: corrupted index.yml in collection '#{@name}', treating as empty"
      []
    end

    def write_index(entries_list)
      File.write(index_path, YAML.dump(entries_list))
    end
  end
end
