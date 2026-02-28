# frozen_string_literal: true

require "test_helper"

class TestEntry < Minitest::Test # rubocop:disable Metrics/ClassLength
  include TestHelpers

  def setup
    setup_test_dir
  end

  def teardown
    teardown_test_dir
  end

  def test_slug_generation
    entry = Mddir::Entry.new(
      url: "https://example.com/article",
      title: "My Great Article",
      description: "A test",
      markdown: "# Hello",
      conversion: "local",
      token_count: 50,
      token_estimated: true
    )

    assert_match(/\Amy-great-article-[a-f0-9]{6}\z/, entry.slug)
    assert_equal "#{entry.slug}.md", entry.filename
  end

  def test_slug_uses_url_hash
    entry1 = Mddir::Entry.new(
      url: "https://example.com/a",
      title: "Same Title",
      description: "",
      markdown: "# A",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    entry2 = Mddir::Entry.new(
      url: "https://example.com/b",
      title: "Same Title",
      description: "",
      markdown: "# B",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    refute_equal entry1.slug, entry2.slug
  end

  def test_to_index_entry
    entry = Mddir::Entry.new(
      url: "https://example.com/article",
      title: "Test",
      description: "Desc",
      markdown: "# Content",
      conversion: "cloudflare",
      token_count: 100,
      token_estimated: false
    )

    idx = entry.to_index_entry

    assert_equal "https://example.com/article", idx["url"]
    assert_equal "Test", idx["title"]
    assert_equal "Desc", idx["description"]
    assert_equal "cloudflare", idx["conversion"]
    assert_equal 100, idx["token_count"]
    refute idx["token_estimated"]
  end

  def test_markdown_with_frontmatter
    entry = Mddir::Entry.new(
      url: "https://example.com/article",
      title: "Test",
      description: "Desc",
      markdown: "# Hello World\n\nContent here.",
      conversion: "local",
      token_count: 50,
      token_estimated: true
    )

    md = entry.to_markdown_with_frontmatter

    assert md.start_with?("---\n")
    assert_includes md, "url: https://example.com/article"
    assert_includes md, "# Hello World"
  end

  def test_strips_existing_frontmatter
    original_md = "---\ntitle: Original\nauthor: Someone\n---\n\n# Article\n\nBody text."
    entry = Mddir::Entry.new(
      url: "https://example.com/cf",
      title: "Original",
      description: "",
      markdown: original_md,
      conversion: "cloudflare",
      token_count: 50,
      token_estimated: false
    )

    md = entry.to_markdown_with_frontmatter

    assert_includes md, "# Article"
    assert_includes md, "Body text."
    assert_includes md, "url: https://example.com/cf"
  end

  def test_save_to
    collection = Mddir::Collection.new("test", @config)
    collection.create!

    entry = Mddir::Entry.new(
      url: "https://example.com/save-test",
      title: "Save Test",
      description: "Testing save",
      markdown: "# Saved",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    entry.save_to(collection.path)

    assert_path_exists File.join(collection.path, entry.filename)
  end

  def test_empty_title_produces_untitled_slug
    entry = Mddir::Entry.new(
      url: "https://example.com/no-title",
      title: "",
      description: "",
      markdown: "# Content",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    assert entry.slug.start_with?("untitled-")
  end

  def test_nil_title_handled_gracefully
    entry = Mddir::Entry.new(
      url: "https://example.com/nil-title",
      title: nil,
      description: nil,
      markdown: "# Content",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    refute_nil entry.slug
    refute_empty entry.slug
    refute_nil entry.filename
  end

  def test_frontmatter_safely_serializes_special_characters # rubocop:disable Metrics/AbcSize
    collection = Mddir::Collection.new("test", @config)
    collection.create!

    entry = Mddir::Entry.new(
      url: "https://example.com/special",
      title: 'Title: with "quotes" & colons',
      description: "Line one\nLine two",
      markdown: "# Content",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    entry.save_to(collection.path)
    file_content = File.read(File.join(collection.path, entry.filename))

    # Parse the frontmatter back — must roundtrip without corruption
    parts = file_content.split("---", 3)
    parsed = YAML.safe_load(parts[1])

    assert_equal 'Title: with "quotes" & colons', parsed["title"]
    assert_equal entry.url, parsed["url"]
  end

  def test_cloudflare_frontmatter_stripped_and_replaced
    cf_markdown = <<~MD
      ---
      title: "CF Title"
      author: "Original Author"
      tags: ["ruby", "web"]
      ---

      # Article Heading

      The actual article content.
    MD

    entry = Mddir::Entry.new(
      url: "https://example.com/cf-page",
      title: "CF Title",
      description: "CF desc",
      markdown: cf_markdown,
      conversion: "cloudflare",
      token_count: 100,
      token_estimated: false
    )

    md = entry.to_markdown_with_frontmatter

    # Should have mddir's frontmatter, not the original Cloudflare one
    assert_includes md, "url: https://example.com/cf-page"
    assert_includes md, "conversion: cloudflare"

    # Original content preserved
    assert_includes md, "# Article Heading"
    assert_includes md, "The actual article content."

    # Should not have double frontmatter blocks
    assert_equal 2, md.scan("---").count
  end

  def test_saved_at_is_utc_iso8601
    entry = Mddir::Entry.new(
      url: "https://example.com/time",
      title: "Time Test",
      description: "",
      markdown: "# Content",
      conversion: "local",
      token_count: 10,
      token_estimated: true
    )

    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, entry.saved_at)
  end
end
