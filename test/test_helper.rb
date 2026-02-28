# frozen_string_literal: true

# Suppress warnings from third-party gems (rouge, kramdown, etc.)
# while keeping warnings from our own code visible.
$VERBOSE = nil
module Warning
  def warn(message, category: nil)
    return if message.include?("/gems/")

    super
  end
end
$VERBOSE = true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "webmock"
require "httpx"
require "httpx/adapters/webmock"
require "webmock/minitest"

require "mddir"
require "tmpdir"
require "fileutils"

module TestHelpers # rubocop:disable Style/OneClassPerFile
  def setup_test_dir
    @test_dir = Dir.mktmpdir("mddir-test")
    @config = Mddir::Config.new
    @config.instance_variable_set(:@data, @config.instance_variable_get(:@data).merge("base_dir" => @test_dir))
  end

  def teardown_test_dir
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end

  def create_test_collection(name, entries: [])
    collection = Mddir::Collection.new(name, @config)
    collection.create!
    entries.each { |entry_data| add_test_entry(collection, entry_data) }
    collection
  end

  private

  def add_test_entry(collection, entry_data)
    defaults = build_entry_defaults(entry_data)
    collection.add_entry(defaults)
    write_test_markdown(collection.path, defaults, entry_data[:content])
  end

  def build_entry_defaults(entry_data)
    slug = entry_data[:slug] || "test-page-abc123"

    {
      "url" => "https://example.com/#{slug}",
      "title" => entry_data[:title] || "Test Page",
      "description" => entry_data[:description] || "A test page",
      "filename" => "#{slug}.md",
      "slug" => slug,
      "saved_at" => Time.now.utc.iso8601,
      "conversion" => "local",
      "token_count" => 100,
      "token_estimated" => true
    }
  end

  def write_test_markdown(collection_path, defaults, content)
    md_content = <<~MD
      ---
      url: #{defaults["url"]}
      title: "#{defaults["title"]}"
      ---

      # #{defaults["title"]}

      #{content || "This is test content."}
    MD

    File.write(File.join(collection_path, defaults["filename"]), md_content)
  end
end
