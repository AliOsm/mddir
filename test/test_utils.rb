# frozen_string_literal: true

require "test_helper"

class TestUtils < Minitest::Test
  def test_slugify_downcases
    assert_equal "hello-world", Mddir::Utils.slugify("Hello World")
  end

  def test_slugify_replaces_special_chars
    assert_equal "foo-bar-baz", Mddir::Utils.slugify("foo@bar!baz")
  end

  def test_slugify_collapses_multiple_dashes
    assert_equal "foo-bar", Mddir::Utils.slugify("foo---bar")
  end

  def test_slugify_strips_leading_trailing_dashes
    assert_equal "foo", Mddir::Utils.slugify("-foo-")
  end

  def test_slugify_handles_empty_string
    assert_equal "", Mddir::Utils.slugify("")
  end

  def test_strip_frontmatter_removes_yaml_block
    text = "---\ntitle: Hello\n---\nContent here"

    assert_equal "Content here", Mddir::Utils.strip_frontmatter(text)
  end

  def test_strip_frontmatter_returns_text_without_frontmatter
    text = "Just plain content"

    assert_equal "Just plain content", Mddir::Utils.strip_frontmatter(text)
  end

  def test_strip_frontmatter_handles_empty_frontmatter
    text = "---\n---\nContent"

    assert_equal "Content", Mddir::Utils.strip_frontmatter(text)
  end

  def test_skip_frontmatter_skips_yaml_block
    lines = ["---\n", "title: Test\n", "---\n", "Line one\n", "Line two\n"]
    result = Mddir::Utils.skip_frontmatter(lines)

    assert_equal [[4, "Line one"], [5, "Line two"]], result
  end

  def test_skip_frontmatter_includes_all_lines_without_frontmatter
    lines = ["Line one\n", "Line two\n"]
    result = Mddir::Utils.skip_frontmatter(lines)

    assert_equal [[1, "Line one"], [2, "Line two"]], result
  end

  def test_skip_frontmatter_returns_empty_for_empty_input
    assert_equal [], Mddir::Utils.skip_frontmatter([])
  end
end
