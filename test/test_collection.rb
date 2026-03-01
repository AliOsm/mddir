# frozen_string_literal: true

require "English"
require "test_helper"
require "mddir/search_index"

class TestCollection < Minitest::Test # rubocop:disable Metrics/ClassLength
  include TestHelpers

  def setup
    setup_test_dir
  end

  def teardown
    teardown_test_dir
  end

  def test_slugify
    assert_equal "ruby", Mddir::Utils.slugify("Ruby")
    assert_equal "ai-research", Mddir::Utils.slugify("AI Research")
    assert_equal "my-collection", Mddir::Utils.slugify("  My--Collection!!  ")
    assert_equal "test-123", Mddir::Utils.slugify("test 123")
  end

  def test_create_collection
    collection = Mddir::Collection.new("ruby", @config)

    refute_predicate collection, :exist?

    collection.create!

    assert_predicate collection, :exist?
    assert_path_exists collection.index_path
    assert_equal 0, collection.entry_count
  end

  def test_create_existing_collection
    collection = Mddir::Collection.new("ruby", @config)
    collection.create!
    collection.create! # should not raise

    assert_predicate collection, :exist?
  end

  def test_add_entry
    collection = create_test_collection("ruby")
    entry_data = {
      "url" => "https://example.com/fibers",
      "title" => "Ruby Fibers",
      "description" => "About fibers",
      "filename" => "ruby-fibers-abc123.md",
      "slug" => "ruby-fibers-abc123",
      "saved_at" => Time.now.utc.iso8601,
      "conversion" => "local",
      "token_count" => 200,
      "token_estimated" => true
    }

    assert collection.add_entry(entry_data)
    assert_equal(1, collection.entries.count { |entry| entry["url"] == "https://example.com/fibers" })
  end

  def test_duplicate_entry_rejected
    collection = create_test_collection("ruby")
    entry_data = {
      "url" => "https://example.com/fibers",
      "title" => "Ruby Fibers",
      "description" => "About fibers",
      "filename" => "ruby-fibers-abc123.md",
      "slug" => "ruby-fibers-abc123",
      "saved_at" => Time.now.utc.iso8601,
      "conversion" => "local",
      "token_count" => 200,
      "token_estimated" => true
    }

    assert collection.add_entry(entry_data)
    refute collection.add_entry(entry_data) # duplicate
  end

  def test_find_entry_by_index
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-one-abc123", title: "Page One" },
                                          { slug: "page-two-def456", title: "Page Two" }
                                        ])

    entry = collection.find_entry("1")

    assert_equal "Page One", entry["title"]

    entry = collection.find_entry("2")

    assert_equal "Page Two", entry["title"]
  end

  def test_find_entry_by_slug
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-one-abc123", title: "Page One" }
                                        ])

    entry = collection.find_entry("page-one-abc123")

    assert_equal "Page One", entry["title"]

    entry = collection.find_entry("page-one-abc123.md")

    assert_equal "Page One", entry["title"]
  end

  def test_remove_entry
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-one-abc123", title: "Page One" }
                                        ])

    removed = collection.remove_entry("1")

    assert_equal "Page One", removed["title"]
    assert_equal 0, collection.entry_count
  end

  def test_remove_collection
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-one-abc123", title: "Page One" }
                                        ])

    collection.remove!

    refute_predicate collection, :exist?
  end

  def test_remove_collection_cleans_search_index
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-abc123", title: "Page",
                                            content: "searchable content here" }
                                        ])

    searcher = Mddir::Search.new(@config)

    assert_equal 1, searcher.search("searchable").length

    collection.remove!

    assert_empty searcher.search("searchable")
  end

  def test_all_collections
    create_test_collection("alpha")
    create_test_collection("beta")

    all = Mddir::Collection.all(@config)
    names = all.map(&:name)

    assert_includes names, "alpha"
    assert_includes names, "beta"
  end

  def test_all_returns_empty_when_base_dir_missing
    config = Mddir::Config.new
    config.instance_variable_set(:@data, { "base_dir" => "/tmp/mddir-nonexistent-#{$PROCESS_ID}" })

    assert_empty Mddir::Collection.all(config)
  end

  def test_all_ignores_files_in_base_dir
    File.write(File.join(@test_dir, "stray-file.txt"), "not a collection")
    create_test_collection("real")

    names = Mddir::Collection.all(@config).map(&:name)

    assert_includes names, "real"
    refute_includes names, "stray-file.txt"
  end

  def test_corrupted_index_treated_as_empty
    collection = Mddir::Collection.new("broken", @config)
    collection.create!
    File.write(collection.index_path, "{{{{ not valid yaml !!!!")

    assert_equal 0, collection.entry_count
    assert_empty collection.entries
  end

  def test_find_entry_returns_nil_for_bad_index
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-abc123", title: "Page" }
                                        ])

    assert_nil collection.find_entry("99")
    assert_nil collection.find_entry("0")
    assert_nil collection.find_entry("nonexistent-slug")
  end

  def test_remove_entry_returns_nil_for_nonexistent
    collection = create_test_collection("ruby")

    assert_nil collection.remove_entry("nonexistent")
    assert_nil collection.remove_entry("99")
  end

  def test_remove_entry_deletes_markdown_file
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-abc123", title: "Page" }
                                        ])
    file_path = File.join(collection.path, "page-abc123.md")

    assert_path_exists file_path

    collection.remove_entry("page-abc123")

    refute_path_exists file_path
  end

  def test_last_added_with_entries
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-abc123", title: "Page" }
                                        ])

    refute_nil collection.last_added
  end

  def test_last_added_empty_collection
    collection = create_test_collection("ruby")

    assert_nil collection.last_added
  end

  def test_collection_names_are_slugified
    collection = Mddir::Collection.new("My Cool Collection!", @config)

    assert_equal "my-cool-collection", collection.name
  end

  def test_adding_entry_persists_across_reads
    collection = create_test_collection("ruby")
    collection.add_entry({
                           "url" => "https://example.com/persist",
                           "title" => "Persist Test",
                           "description" => "",
                           "filename" => "persist-abc123.md",
                           "slug" => "persist-abc123",
                           "saved_at" => Time.now.utc.iso8601,
                           "conversion" => "local",
                           "token_count" => 50,
                           "token_estimated" => true
                         })

    fresh = Mddir::Collection.new("ruby", @config)

    assert_equal 1, fresh.entry_count
    assert_equal "Persist Test", fresh.entries.first["title"]
  end
end
