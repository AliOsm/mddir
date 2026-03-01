# frozen_string_literal: true

require "test_helper"
require "mddir/search"

class TestSearch < Minitest::Test # rubocop:disable Metrics/ClassLength
  include TestHelpers

  def setup
    setup_test_dir
  end

  def teardown
    teardown_test_dir
  end

  def test_search_finds_matches
    create_test_collection("ruby", entries: [
                             {
                               slug: "fibers-abc123",
                               title: "Ruby Fibers",
                               content: "Fibers are lightweight concurrency primitives."
                             }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("lightweight")

    assert_equal 1, results.length
    assert_equal "ruby", results.first.collection_name
    assert_equal "Ruby Fibers", results.first.entry["title"]
    refute_empty results.first.matches
  end

  def test_search_case_insensitive
    create_test_collection("ruby", entries: [
                             { slug: "test-abc123", title: "Test", content: "Ruby is GREAT for scripting." }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("great")

    assert_equal 1, results.length
  end

  def test_search_skips_frontmatter
    create_test_collection("ruby", entries: [
                             { slug: "test-abc123", title: "Test", content: "Regular body content." }
                           ])

    searcher = Mddir::Search.new(@config)
    # "source:" only appears in frontmatter
    results = searcher.search("source:")

    assert_equal 0, results.length
  end

  def test_search_scoped_to_collection
    create_test_collection("ruby", entries: [
                             { slug: "ruby-page-abc123", title: "Ruby Page", content: "unique_keyword_ruby here" }
                           ])
    create_test_collection("python", entries: [
                             { slug: "python-page-abc123", title: "Python Page", content: "unique_keyword_python here" }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("unique_keyword_ruby", collection_name: "ruby")

    assert_equal 1, results.length
    assert_equal "ruby", results.first.collection_name
  end

  def test_search_no_results
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page", content: "Nothing matching here." }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("xyznonexistent")

    assert_empty results
  end

  def test_multiple_matches_in_single_file
    create_test_collection("ruby", entries: [
                             { slug: "fibers-abc123", title: "Fibers",
                               content: "Fibers are great.\nMore about fibers.\nEven more fibers here." }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("fibers")

    assert_equal 1, results.length
    assert_operator results.first.matches.length, :>=, 2
  end

  def test_search_across_all_collections
    create_test_collection("ruby", entries: [
                             { slug: "ruby-page-abc123", title: "Ruby Page", content: "shared_keyword in ruby" }
                           ])
    create_test_collection("python", entries: [
                             { slug: "python-page-abc123", title: "Python Page", content: "shared_keyword in python" }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("shared_keyword")

    collection_names = results.map(&:collection_name)

    assert_includes collection_names, "ruby"
    assert_includes collection_names, "python"
  end

  def test_search_nonexistent_collection_returns_empty
    searcher = Mddir::Search.new(@config)
    results = searcher.search("anything", collection_name: "nonexistent")

    assert_empty results
  end

  def test_snippet_adds_ellipsis_for_long_lines
    long_line = "#{"a" * 60}TARGET#{"b" * 60}"
    create_test_collection("ruby", entries: [
                             { slug: "long-abc123", title: "Long Lines", content: long_line }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("TARGET")

    snippet = results.first.matches.first.snippet

    assert_includes snippet, "TARGET"
    assert_includes snippet, "...", "Expected ellipsis in snippet for long line"
  end

  def test_matches_include_line_numbers
    create_test_collection("ruby", entries: [
                             {
                               slug: "lines-abc123",
                               title: "Lines",
                               content: "Line one.\nLine two.\nLine three has keyword."
                             }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("keyword")

    match = results.first.matches.first

    assert_operator match.line_number, :>, 0
  end

  def test_search_results_ordered_by_relevance
    create_test_collection("aaa-sparse", entries: [
                             { slug: "sparse-abc123", title: "Sparse",
                               content: "this line has relevance_keyword among many other unrelated words" }
                           ])
    create_test_collection("zzz-dense", entries: [
                             { slug: "dense-abc123", title: "Dense",
                               content: "relevance_keyword relevance_keyword relevance_keyword" }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("relevance_keyword")

    assert_equal 2, results.length
    assert_equal "zzz-dense", results.first.collection_name,
                 "Expected denser match to rank first, not alphabetical order"
  end

  def test_search_returns_entry_metadata
    create_test_collection("ruby", entries: [
                             { slug: "meta-abc123", title: "Meta Entry", content: "findable content here" }
                           ])

    searcher = Mddir::Search.new(@config)
    results = searcher.search("findable")

    entry = results.first.entry

    assert_equal "Meta Entry", entry["title"]
    assert_equal "meta-abc123.md", entry["filename"]
    assert_equal "https://example.com/meta-abc123", entry["url"]
  end
end
