# frozen_string_literal: true

require "test_helper"

class TestGlobalIndex < Minitest::Test
  include TestHelpers

  def setup
    setup_test_dir
  end

  def teardown
    teardown_test_dir
  end

  def test_rebuild_creates_index
    create_test_collection("ruby", entries: [
                             { slug: "page-one-abc123", title: "Page One" },
                             { slug: "page-two-def456", title: "Page Two" }
                           ])
    create_test_collection("python")

    data = Mddir::GlobalIndex.update!(@config)

    assert_equal 2, data["collections"]["ruby"]["entry_count"]
    assert_equal 0, data["collections"]["python"]["entry_count"]
    assert_equal 2, data["total_entries"]
  end

  def test_load_rebuilds_if_missing
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])

    # Remove global index
    index_path = Mddir::GlobalIndex.path(@config)
    FileUtils.rm_f(index_path)

    data = Mddir::GlobalIndex.load!(@config)

    assert_equal 1, data["total_entries"]
  end

  def test_load_rebuilds_corrupted_index
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])

    File.write(Mddir::GlobalIndex.path(@config), "{{{{ invalid yaml !!!!")

    data = Mddir::GlobalIndex.load!(@config)

    assert_equal 1, data["total_entries"]
    assert_equal 1, data["collections"]["ruby"]["entry_count"]
  end

  def test_rebuild_with_empty_base_dir
    data = Mddir::GlobalIndex.update!(@config)

    assert_equal 0, data["total_entries"]
    assert_empty data["collections"]
  end

  def test_rebuild_writes_file_to_disk
    create_test_collection("ruby", entries: [
                             { slug: "page-abc123", title: "Page" }
                           ])

    Mddir::GlobalIndex.update!(@config)

    assert_path_exists Mddir::GlobalIndex.path(@config)
    data = YAML.safe_load_file(Mddir::GlobalIndex.path(@config))

    assert_equal 1, data["total_entries"]
  end

  def test_index_stays_in_sync_after_mutations
    collection = create_test_collection("ruby", entries: [
                                          { slug: "page-one-abc123", title: "Page One" },
                                          { slug: "page-two-def456", title: "Page Two" }
                                        ])

    data = Mddir::GlobalIndex.load!(@config)

    assert_equal 2, data["collections"]["ruby"]["entry_count"]

    collection.remove_entry("1")

    data = Mddir::GlobalIndex.load!(@config)

    assert_equal 1, data["collections"]["ruby"]["entry_count"]
    assert_equal 1, data["total_entries"]
  end
end
