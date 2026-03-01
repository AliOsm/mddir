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
      @index_corrupt = false
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
      @entries ||= load_index
    end

    def entry_count
      entries.length
    end

    def url?(url)
      entries.any? { |entry| entry["url"] == url }
    end

    def last_added
      entries_list = entries
      return nil if entries_list.empty?

      entries_list.map { |entry| entry["saved_at"] }.compact.max
    end

    def find_entry(identifier)
      entry = find_entry_by_slug(identifier)
      return entry if entry

      return unless identifier.match?(/\A\d+\z/)

      index = identifier.to_i - 1
      entries[index] if index >= 0 && index < entries.length
    end

    def find_entry_by_slug(slug)
      slug = slug.delete_suffix(".md")
      entries.find { |entry| entry["slug"] == slug }
    end

    def index_path
      File.join(@path, "index.yml")
    end

    def create!
      FileUtils.mkdir_p(@path)
      write_index([]) unless File.exist?(index_path)
      GlobalIndex.update!(@config)
      self
    end

    def add_entry(entry_data)
      raise CorruptIndexError, "Cannot add entry: index.yml in '#{@name}' is corrupted" if @index_corrupt

      entries_list = entries
      return nil if entries_list.any? { |entry| entry["url"] == entry_data["url"] }

      entries_list << entry_data
      write_index(entries_list)
      GlobalIndex.update!(@config)
      entry_data
    end

    def remove_entry(identifier)
      raise CorruptIndexError, "Cannot remove entry: index.yml in '#{@name}' is corrupted" if @index_corrupt

      entry = find_entry(identifier)
      return nil unless entry

      file_path = File.join(@path, entry["filename"])
      FileUtils.rm_f(file_path)

      entries_list = entries.reject { |list_entry| list_entry["filename"] == entry["filename"] }
      write_index(entries_list)
      GlobalIndex.update!(@config)
      entry
    end

    def remove!
      FileUtils.rm_rf(@path)
      GlobalIndex.update!(@config)
      SearchIndex.open(@config) { |index| index.remove_collection!(name) }
    end

    private

    def load_index
      return [] unless File.exist?(index_path)

      data = YAML.safe_load_file(index_path, permitted_classes: [Time])
      data.is_a?(Array) ? data : []
    rescue Psych::SyntaxError => e
      @index_corrupt = true
      warn "Warning: corrupted index.yml in collection '#{@name}' (#{e.message})"
      []
    end

    def write_index(entries_list)
      @entries = nil
      File.write(index_path, YAML.dump(entries_list))
    end
  end
end
