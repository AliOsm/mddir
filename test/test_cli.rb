# frozen_string_literal: true

require "test_helper"

class TestCLI < Minitest::Test # rubocop:disable Metrics/ClassLength
  include TestHelpers

  def setup
    setup_test_dir
    @cli = Mddir::CLI.new
    @cli.instance_variable_set(:@config, @config)
  end

  def teardown
    teardown_test_dir
  end

  def test_ls_with_no_collections
    out, = run_cli { @cli.ls }

    assert_match(/No collections/, out)
  end

  def test_ls_lists_collections
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])
    Mddir::GlobalIndex.update!(@config)

    out, = run_cli { @cli.ls }

    assert_match(/ruby/, out)
    assert_match(/1 entry/, out)
  end

  def test_ls_collection_entries
    create_test_collection("ruby", entries: [
                             { slug: "page-one-abc123", title: "Page One" },
                             { slug: "page-two-def456", title: "Page Two" }
                           ])

    out, = run_cli { @cli.ls("ruby") }

    assert_match(/Page One/, out)
    assert_match(/Page Two/, out)
    assert_match(/2 entries/, out)
  end

  def test_ls_nonexistent_collection
    out, err = run_cli { @cli.ls("nonexistent") }

    assert_match(/not found/, out + err)
  end

  def test_rm_nonexistent_collection
    out, err = run_cli { @cli.rm("nonexistent") }

    assert_match(/not found/, out + err)
  end

  def test_rm_entry_by_index
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])
    Mddir::GlobalIndex.update!(@config)

    out, = run_cli { @cli.rm("ruby", "1") }

    assert_match(/Removed.*Page/, out)

    collection = Mddir::Collection.new("ruby", @config)

    assert_equal 0, collection.entry_count
  end

  def test_rm_nonexistent_entry
    create_test_collection("ruby")

    out, err = run_cli { @cli.rm("ruby", "99") }

    assert_match(/not found/, out + err)
  end

  def test_reindex
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])

    out, = run_cli { @cli.reindex }

    assert_match(/1 collections/, out)
    assert_match(/1 entries/, out)
  end

  def test_version
    out, = run_cli { @cli.version }

    assert_match(/mddir/, out)
    assert_match Mddir::VERSION, out
  end

  def test_search_no_args
    out, = run_cli { @cli.search }

    assert_match(/Usage/, out)
  end

  def test_search_with_results
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page", content: "Ruby fibers are great" }
                           ])

    out, = run_cli { @cli.search("ruby", "fibers") }

    assert_match(/fibers/, out)
    assert_match(/Page/, out)
  end

  def test_search_no_matches
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page", content: "Hello world" }
                           ])

    out, = run_cli { @cli.search("ruby", "nonexistent-xyz") }

    assert_match(/No matches/, out)
  end

  def test_add_no_urls
    out, err = run_cli { @cli.add("ruby") }

    assert_match(/at least one URL/, out + err)
  end

  def test_add_duplicate_url
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])

    out, = run_cli { @cli.add("ruby", "https://example.com/page-abc123") }

    assert_match(/Skipped.*duplicate/, out)
  end

  def test_add_fetch_error
    create_test_collection("ruby")
    stub_request(:get, "https://example.com/broken").to_timeout

    out, err = run_cli { @cli.add("ruby", "https://example.com/broken") }

    assert_match(/Error fetching.*broken/, out + err)
  end

  private

  def run_cli # rubocop:disable Metrics/MethodLength
    out = StringIO.new
    err = StringIO.new

    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = out
    $stderr = err

    yield

    [out.string, err.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end
