# frozen_string_literal: true

require "sinatra/base"
require "kramdown"
require "kramdown-parser-gfm"
require "rouge"
require "uri"
require_relative "search"

module Mddir
  class Server < Sinatra::Base # rubocop:disable Metrics/ClassLength
    set :views, File.expand_path("../../views", __dir__)
    set :public_folder, File.expand_path("../../public", __dir__)

    enable :method_override

    before do
      @collection_names = Collection.all(config).map(&:name)
    end

    def self.start(config)
      set :mddir_config, config
      set :port, config.port
      set :bind, "localhost"

      puts "mddir server running at http://localhost:#{config.port}"
      puts "Press Ctrl+C to stop"
      run!
    end

    helpers do # rubocop:disable Metrics/BlockLength
      def config
        settings.mddir_config
      end

      def format_date(date_str)
        return "" unless date_str

        Time.parse(date_str.to_s).strftime("%b %d, %Y")
      rescue ArgumentError
        date_str.to_s
      end

      def domain_from_url(url)
        URI.parse(url).host
      rescue URI::InvalidURIError
        url
      end

      def truncate(text, length = 200)
        return "" unless text

        text.length > length ? "#{text[0, length]}..." : text
      end

      def h(text)
        Rack::Utils.escape_html(text.to_s)
      end

      def format_tokens(count)
        return "" unless count

        count >= 1000 ? "~#{(count / 1000.0).round(1)}k tokens" : "~#{count} tokens"
      end

      def highlight(text, query)
        return h(text) unless query && !query.empty?

        escaped_query = Regexp.escape(query)
        h(text).gsub(/#{escaped_query}/i) { |m| "<mark>#{m}</mark>" }
      end
    end

    get "/" do
      @global = GlobalIndex.load(config)
      @collections = (@global["collections"] || {}).sort_by { |name, _| name }

      erb :home
    end

    get "/search" do
      @query = params["q"].to_s.strip
      @collection_filter = params["collection"]

      if @query.empty?
        @results = []
      else
        searcher = Search.new(config)
        @results = searcher.search(@query, collection_name: @collection_filter)
      end

      erb :search
    end

    get "/:collection" do
      collection = Collection.new(params[:collection], config)
      halt 404, "Collection not found" unless collection.exist?

      @collection = collection
      @current_collection = collection.name
      @entries = collection.entries.reverse

      erb :collection
    end

    get "/:collection/:slug" do
      collection = Collection.new(params[:collection], config)
      halt 404, "Collection not found" unless collection.exist?

      @collection = collection
      @current_collection = collection.name
      @entry = collection.entries.find { |entry| entry["slug"] == params[:slug] }
      halt 404, "Entry not found" unless @entry

      file_path = File.join(collection.path, @entry["filename"])
      halt 404, "File not found" unless File.exist?(file_path)

      raw = File.read(file_path, encoding: "UTF-8")
      content = Utils.strip_frontmatter(raw)
      @html_content = Kramdown::Document.new(
        content,
        input: "GFM",
        syntax_highlighter: :rouge,
        syntax_highlighter_opts: {
          default_lang: "plaintext"
        }
      ).to_html

      erb :reader
    end

    delete "/:collection" do
      collection = Collection.new(params[:collection], config)
      halt 404, "Collection not found" unless collection.exist?

      collection.remove!

      redirect "/"
    end

    delete "/:collection/:slug" do
      collection = Collection.new(params[:collection], config)
      halt 404, "Collection not found" unless collection.exist?

      entry = collection.entries.find { |e| e["slug"] == params[:slug] }
      halt 404, "Entry not found" unless entry

      collection.remove_entry(entry["slug"])

      redirect "/#{collection.name}"
    end
  end
end
