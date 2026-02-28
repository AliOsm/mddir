# frozen_string_literal: true

require "sqlite3"

module Mddir
  class SearchIndex
    def self.open(config)
      index = new(config)
      yield index
    ensure
      index&.close
    end

    def initialize(config)
      @db = SQLite3::Database.new(File.join(config.base_dir, "search.db"))
      @db.results_as_hash = true
      setup_schema
    end

    def ensure_current!(collection)
      row = @db.get_first_row("SELECT indexed_at FROM meta WHERE collection = ?", collection.name)
      return if row && row["indexed_at"] >= index_mtime(collection)

      reindex(collection)
    end

    def query(text, collection_names:)
      escaped = text.gsub('"', '""')
      placeholders = (["?"] * collection_names.size).join(", ")

      @db.execute(
        "SELECT collection, filename, line_number, content FROM search_lines " \
        "WHERE search_lines MATCH ? AND collection IN (#{placeholders}) ORDER BY rank",
        ["\"#{escaped}\"", *collection_names]
      )
    end

    def remove_collection!(collection_name)
      @db.execute("DELETE FROM search_lines WHERE collection = ?", collection_name)
      @db.execute("DELETE FROM meta WHERE collection = ?", collection_name)
    end

    def close
      @db.close
    end

    private

    def setup_schema
      @db.execute_batch(<<~SQL)
        CREATE VIRTUAL TABLE IF NOT EXISTS search_lines USING fts5(
          collection UNINDEXED,
          filename UNINDEXED,
          line_number UNINDEXED,
          content,
          tokenize='trigram case_sensitive 0'
        );

        CREATE TABLE IF NOT EXISTS meta (
          collection TEXT PRIMARY KEY,
          indexed_at REAL NOT NULL
        );
      SQL
    end

    def reindex(collection)
      @db.transaction do
        @db.execute("DELETE FROM search_lines WHERE collection = ?", collection.name)
        index_collection_files(collection)
        update_meta(collection)
      end
    end

    def index_collection_files(collection)
      collection.entries.each do |entry|
        file_path = File.join(collection.path, entry["filename"])
        next unless File.exist?(file_path)

        index_file(collection.name, entry["filename"], file_path)
      end
    end

    def update_meta(collection)
      @db.execute(
        "INSERT OR REPLACE INTO meta (collection, indexed_at) VALUES (?, ?)",
        [collection.name, index_mtime(collection)]
      )
    end

    def index_file(collection_name, filename, file_path)
      lines = File.readlines(file_path, encoding: "UTF-8")

      Utils.skip_frontmatter(lines).each do |line_number, line|
        next if line.strip.empty?

        @db.execute(
          "INSERT INTO search_lines (collection, filename, line_number, content) VALUES (?, ?, ?, ?)",
          [collection_name, filename, line_number, line]
        )
      end
    end

    def index_mtime(collection)
      File.exist?(collection.index_path) ? File.mtime(collection.index_path).to_f : 0.0
    end
  end
end
