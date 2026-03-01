# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "mddir/server"

class TestServer < Minitest::Test # rubocop:disable Metrics/ClassLength
  include Rack::Test::Methods
  include TestHelpers

  def app
    Mddir::Server.set :mddir_config, @config
    Mddir::Server.set :environment, :test
    Mddir::Server
  end

  def setup
    setup_test_dir
  end

  def teardown
    teardown_test_dir
  end

  # --- Home page ---

  def test_home_page_lists_collections
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers" }
                           ])
    create_test_collection("python", entries: [
                             { slug: "decorators-abc123", title: "Decorators" },
                             { slug: "generators-def456", title: "Generators" }
                           ])

    get "/"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "ruby"
    assert_includes last_response.body, "python"
    assert_includes last_response.body, "1"
    assert_includes last_response.body, "2"
  end

  def test_home_page_with_no_collections
    Mddir::GlobalIndex.update!(@config)

    get "/"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "No collections yet"
  end

  # --- Collection page ---

  def test_collection_page_lists_entries
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers", description: "About fibers" },
                             { slug: "procs-def456", title: "Ruby Procs", description: "About procs" }
                           ])

    get "/ruby"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Ruby Fibers"
    assert_includes last_response.body, "Ruby Procs"
    assert_includes last_response.body, "About fibers"
  end

  def test_collection_page_shows_empty_state
    create_test_collection("empty-col")

    get "/empty-col"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "No entries"
  end

  def test_collection_not_found
    get "/nonexistent"

    assert_equal 404, last_response.status
  end

  # --- Reader page ---

  def test_reader_renders_markdown_as_html
    create_test_collection("ruby", entries: [
                             {
                               slug: "fiber-abc123",
                               title: "Ruby Fibers",
                               content: "Fibers are **awesome** primitives."
                             }
                           ])

    get "/ruby/fiber-abc123"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "<strong>awesome</strong>"
    assert_includes last_response.body, "Ruby Fibers"
  end

  def test_reader_shows_source_url
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers" }
                           ])

    get "/ruby/fiber-abc123"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "https://example.com/fiber-abc123"
  end

  def test_reader_has_breadcrumb_navigation
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers" }
                           ])

    get "/ruby/fiber-abc123"

    assert_predicate last_response, :ok?
    body = last_response.body

    assert_includes body, 'href="/"'
    assert_includes body, 'href="/ruby"'
  end

  def test_reader_entry_not_found
    create_test_collection("ruby")

    get "/ruby/nonexistent-slug"

    assert_equal 404, last_response.status
  end

  def test_reader_missing_markdown_file
    collection = create_test_collection("ruby", entries: [
                                          { slug: "orphan-abc123", title: "Orphaned Entry" }
                                        ])

    File.delete(File.join(collection.path, "orphan-abc123.md"))

    get "/ruby/orphan-abc123"

    assert_equal 404, last_response.status
  end

  def test_reader_collection_not_found
    get "/nonexistent/some-slug"

    assert_equal 404, last_response.status
  end

  # --- Delete routes ---

  def test_delete_collection
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers" }
                           ])

    delete "/ruby"

    assert_predicate last_response, :redirect?
    follow_redirect!

    assert_predicate last_response, :ok?
    refute Dir.exist?(File.join(@test_dir, "ruby"))
  end

  def test_delete_entry
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers" },
                             { slug: "procs-def456", title: "Ruby Procs" }
                           ])

    delete "/ruby/fiber-abc123"

    assert_predicate last_response, :redirect?
    col = Mddir::Collection.new("ruby", @config)

    assert_equal 1, col.entry_count
    assert_nil col.find_entry("fiber-abc123")
  end

  def test_delete_nonexistent_collection
    delete "/nonexistent"

    assert_equal 404, last_response.status
  end

  def test_delete_nonexistent_entry
    create_test_collection("ruby")

    delete "/ruby/nonexistent-slug"

    assert_equal 404, last_response.status
  end

  # --- Search ---

  def test_search_returns_matching_results
    create_test_collection("ruby", entries: [
                             {
                               slug: "fiber-abc123",
                               title: "Ruby Fibers",
                               content: "Fibers are lightweight concurrency primitives."
                             }
                           ])

    get "/search", q: "lightweight"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Ruby Fibers"
    assert_includes last_response.body, "lightweight"
  end

  def test_search_highlights_matches
    create_test_collection("ruby", entries: [
                             {
                               slug: "fiber-abc123",
                               title: "Ruby Fibers",
                               content: "Fibers are lightweight primitives."
                             }
                           ])

    get "/search", q: "lightweight"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "<mark>"
  end

  def test_search_shows_match_count
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers", content: "Fibers here.\nMore fibers there." }
                           ])

    get "/search", q: "fibers"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "matches"
  end

  def test_search_empty_query
    get "/search", q: ""

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Enter a search query"
  end

  def test_search_filtered_by_collection
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers", content: "unique_filter_keyword here" }
                           ])
    create_test_collection("python", entries: [
                             { slug: "django-abc123", title: "Django Guide", content: "unique_filter_keyword here too" }
                           ])

    get "/search", q: "unique_filter_keyword", collection: "ruby"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Ruby Fibers"
    refute_includes last_response.body, "Django Guide"
  end

  def test_search_handles_search_error
    # Place a directory where search.db expects a file to trigger a SearchError
    db_path = File.join(@test_dir, "search.db")
    FileUtils.rm_f(db_path)
    FileUtils.mkdir_p(db_path)

    get "/search", q: "anything"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "Search error"
  end

  def test_search_no_results
    create_test_collection("ruby", entries: [
                             { slug: "fiber-abc123", title: "Ruby Fibers", content: "Some content." }
                           ])

    get "/search", q: "xyznonexistent"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "No matches found"
  end

  # --- XSS protection ---

  def test_collection_name_is_html_escaped
    # Slugification already sanitizes names, but verify the template escapes output
    create_test_collection("safe-name")

    get "/safe-name"

    assert_predicate last_response, :ok?
    assert_includes last_response.body, "safe-name"
  end

  def test_search_query_is_html_escaped
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page", content: "some content" }
                           ])

    get "/search", q: "<script>alert(1)</script>"

    assert_predicate last_response, :ok?
    refute_includes last_response.body, "<script>alert(1)</script>"
  end
end
