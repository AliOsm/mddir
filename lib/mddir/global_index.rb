# frozen_string_literal: true

require "fileutils"
require "yaml"

module Mddir
  module GlobalIndex
    def self.path(config)
      File.join(config.base_dir, "index.yml")
    end

    def self.load!(config)
      file = path(config)
      return update!(config) unless File.exist?(file)

      data = YAML.safe_load_file(file, permitted_classes: [Time])
      return update!(config) unless data.is_a?(Hash)

      data
    rescue Psych::SyntaxError => e
      warn "Warning: corrupted global index (#{e.message}), rebuilding"
      update!(config)
    end

    def self.update!(config)
      FileUtils.mkdir_p(config.base_dir)

      collections = build_collections(config)

      data = {
        "collections" => collections,
        "total_entries" => collections.sum { |_, info| info["entry_count"] },
        "last_updated" => Time.now.utc.iso8601
      }

      File.write(path(config), YAML.dump(data))

      data
    end

    def self.build_collections(config)
      Collection.all(config).to_h do |collection|
        [collection.name, {
          "entry_count" => collection.entry_count,
          "last_added" => collection.last_added&.to_s
        }]
      end
    end

    private_class_method :build_collections
  end
end
