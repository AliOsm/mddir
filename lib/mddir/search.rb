# frozen_string_literal: true

module Mddir
  class Search
    Result = Struct.new(:collection_name, :entry, :matches)
    Match = Struct.new(:line_number, :snippet)

    def initialize(config)
      @config = config
    end

    def search(query, collection_name: nil)
      collections = resolve_collections(collection_name)
      return [] if collections.empty?

      SearchIndex.open(@config) do |index|
        collections.each { |collection| index.ensure_current!(collection) }

        rows = index.query(query, collection_names: collections.map(&:name))
        build_results(collections, rows, query)
      end
    end

    private

    def resolve_collections(collection_name)
      if collection_name
        collection = Collection.new(collection_name, @config)
        collection.exist? ? [collection] : []
      else
        Collection.all(@config)
      end
    end

    def build_results(collections, rows, query)
      entries_lookup = build_entries_lookup(collections)
      grouped = rows.group_by { |row| [row["collection"], row["filename"]] }

      grouped.filter_map do |(collection_name, filename), file_rows|
        entry = entries_lookup.dig(collection_name, filename)
        next unless entry

        Result.new(collection_name:, entry:, matches: build_matches(file_rows, query))
      end
    end

    def build_entries_lookup(collections)
      collections.to_h do |collection|
        [collection.name, collection.entries.to_h { |entry| [entry["filename"], entry] }]
      end
    end

    def build_matches(file_rows, query)
      file_rows.map do |row|
        snippet = extract_snippet(row["content"], query)
        Match.new(line_number: row["line_number"].to_i, snippet: snippet)
      end
    end

    def extract_snippet(line, query) # rubocop:disable Metrics/AbcSize
      line = line.strip
      index = line.downcase.index(query.downcase)
      return line[0, 120] unless index

      start = [index - 40, 0].max
      finish = [index + query.length + 80, line.length].min
      snippet = line[start...finish]
      snippet = "...#{snippet}" if start.positive?
      snippet = "#{snippet}..." if finish < line.length
      snippet
    end
  end
end
