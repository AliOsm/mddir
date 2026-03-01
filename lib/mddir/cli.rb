# frozen_string_literal: true

require "thor"

module Mddir
  module CLIConfig
    private

    def config
      @config ||= Config.new
    end
  end

  class CollectionCLI < Thor
    include CLIConfig

    namespace "collection"

    desc "create NAME", "Create a new empty collection"
    def create(name)
      collection = Collection.new(name, config)

      if collection.exist?
        say "Collection '#{collection.name}' already exists"
        return
      end

      collection.create!
      say "Created collection '#{collection.name}'"
    end
  end

  class CLI < Thor # rubocop:disable Metrics/ClassLength
    include CLIConfig

    desc "collection SUBCOMMAND", "Manage collections"
    subcommand "collection", CollectionCLI

    desc "version", "Print version"
    def version
      puts "mddir #{Mddir::VERSION}"
    end

    desc "add COLLECTION URL [URL...]", "Fetch web pages and save to a collection"
    method_option :cookies, type: :string, desc: "Path to a cookies file"
    def add(collection_name, *urls)
      if urls.empty?
        say_error "Error: provide at least one URL"
        return
      end

      collection = Collection.new(collection_name, config)
      collection.create! unless collection.exist?

      require_relative "fetcher"
      fetcher = Fetcher.new(config, cookies_path: options[:cookies])
      urls.each { |url| fetch_and_save(url, collection, fetcher) }
    end

    desc "ls [COLLECTION]", "List collections or entries in a collection"
    def ls(collection_name = nil)
      if collection_name
        list_collection_entries(collection_name)
      else
        list_collections
      end
    end

    desc "rm COLLECTION [ENTRY]", "Remove a collection or entry"
    def rm(collection_name, entry_identifier = nil)
      collection = Collection.new(collection_name, config)

      unless collection.exist?
        say_error "Error: collection '#{collection.name}' not found"
        return
      end

      if entry_identifier
        remove_entry(collection, entry_identifier)
      else
        remove_collection(collection)
      end
    end

    desc "search [COLLECTION] QUERY", "Search entries for a query string"
    def search(*args)
      if args.empty?
        say "Usage: mddir search [collection] <query>"
        return
      end

      collection_name = args.length >= 2 ? args[0] : nil
      query = args.length >= 2 ? args[1..].join(" ") : args[0]

      require_relative "search"
      results = Search.new(config).search(query, collection_name:)
      results.empty? ? say("No matches found") : print_search_results(results)
    end

    desc "config", "Open configuration file in editor"
    map "config" => :edit_config
    def edit_config
      config.create_default_config!
      system(config.editor, config.path)
    end

    desc "reindex", "Rebuild the global index from per-collection indexes"
    def reindex
      data = GlobalIndex.update!(config)
      collection_count = data["collections"]&.length || 0
      total = data["total_entries"] || 0
      say "Reindexed #{collection_count} collections, #{total} entries"
    end

    desc "serve", "Start the web UI server"
    def serve
      require_relative "server"
      Server.start(config)
    end

    desc "open", "Start the web UI server and open in browser"
    def open
      require_relative "server"

      url = "http://localhost:#{config.port}"
      Thread.new do
        sleep 1
        open_browser(url)
      end

      Server.start(config)
    end

    private

    def fetch_and_save(url, collection, fetcher)
      if collection.entries.any? { |entry| entry["url"] == url }
        say "Skipped (duplicate): #{url}"
        return
      end

      entry = fetcher.fetch(url)
      entry.save_to(collection.path)
      collection.add_entry(entry.to_index_entry)
      say "Saved: #{entry.filename} → #{collection.name} (#{entry.conversion})"
    rescue FetchError, StandardError => e
      say_error "Error fetching #{url}: #{e.message}"
    end

    def list_collections
      collections = GlobalIndex.load(config)["collections"] || {}

      if collections.empty?
        say "No collections"
        return
      end

      collections.each do |name, info|
        count = info["entry_count"] || 0
        label = count == 1 ? "entry" : "entries"
        say "#{name.ljust(16)} | #{count} #{label}"
      end
    end

    def list_collection_entries(collection_name)
      collection = Collection.new(collection_name, config)

      unless collection.exist?
        say_error "Error: collection '#{collection.name}' not found"
        return
      end

      entries = collection.entries
      count = entries.length
      label = count == 1 ? "entry" : "entries"
      say "#{collection.name} (#{count} #{label})\n\n"

      entries.each_with_index { |entry, idx| print_entry(entry, idx + 1) }
    end

    def print_entry(entry, number)
      say "  #{number}. #{entry["title"]}"
      say "     #{entry["description"]}" unless entry["description"].to_s.empty?
      say "     #{entry["filename"]}"
      say "     #{entry["url"]}"
      say
    end

    def remove_entry(collection, identifier)
      entry = collection.remove_entry(identifier)

      if entry
        say "Removed: #{entry["title"]}"
      else
        say_error "Error: entry not found"
      end
    end

    def remove_collection(collection)
      count = collection.entry_count
      label = count == 1 ? "entry" : "entries"

      if yes?("Remove collection '#{collection.name}' with #{count} #{label}? [y/N]")
        collection.remove!
        say "Removed collection '#{collection.name}'"
      else
        say "Cancelled"
      end
    end

    def print_search_results(results)
      total_matches = results.sum { |result| result.matches.length }
      say "\nFound #{total_matches} matches in #{results.length} files\n\n"

      results.each { |result| print_search_result(result) }
    end

    def print_search_result(result)
      say "[#{result.collection_name}] #{result.entry["title"]}"
      say "  #{result.entry["filename"]}"
      say "  #{result.entry["url"]}"
      result.matches.each { |match| say "  Line #{match.line_number}: #{match.snippet}" }
      say
    end

    def open_browser(url)
      case RUBY_PLATFORM
      when /darwin/
        system("open", url)
      when /linux/
        system("xdg-open", url)
      when /mswin|mingw/
        system("start", url)
      end
    end
  end
end
