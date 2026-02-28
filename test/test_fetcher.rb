# frozen_string_literal: true

require "test_helper"

class TestFetcher < Minitest::Test # rubocop:disable Metrics/ClassLength
  include TestHelpers

  def setup
    setup_test_dir
  end

  def teardown
    teardown_test_dir
  end

  def test_fetch_html_page
    html = <<~HTML
      <html>
      <head>
        <title>Ruby Fibers Guide</title>
        <meta name="description" content="Learn about Ruby fibers">
      </head>
      <body>
        <article>
          <h1>Ruby Fibers Guide</h1>
          <p>Fibers are lightweight concurrency primitives in Ruby.</p>
          <p>They allow you to pause and resume execution.</p>
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/fibers")
      .to_return(
        status: 200,
        body: html,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/fibers")

    assert_equal "https://example.com/fibers", entry.url
    assert_equal "local", entry.conversion
    assert entry.token_estimated
    refute_empty entry.markdown
    assert_includes entry.description, "Ruby fibers"
  end

  def test_fetch_markdown_response
    md = <<~MD
      ---
      title: "Cloudflare Article"
      description: "A CF article"
      ---

      # Cloudflare Article

      This content was returned as markdown.
    MD

    stub_request(:get, "https://cf-site.com/article")
      .to_return(
        status: 200,
        body: md,
        headers: {
          "Content-Type" => "text/markdown",
          "x-markdown-tokens" => "250"
        }
      )

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://cf-site.com/article")

    assert_equal "cloudflare", entry.conversion
    assert_equal "Cloudflare Article", entry.title
    assert_equal "A CF article", entry.description
    assert_equal 250, entry.token_count
    refute entry.token_estimated
  end

  def test_fetch_markdown_without_token_header
    md = <<~MD
      ---
      title: "No Tokens Header"
      description: "Missing header"
      ---

      # Article

      Some content here for testing.
    MD

    stub_request(:get, "https://cf-site.com/no-tokens")
      .to_return(
        status: 200,
        body: md,
        headers: { "Content-Type" => "text/markdown" }
      )

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://cf-site.com/no-tokens")

    assert_equal "cloudflare", entry.conversion
    assert entry.token_estimated
    assert_operator entry.token_count, :>, 0
  end

  def test_fetch_markdown_without_frontmatter
    stub_request(:get, "https://example.com/bare-md")
      .to_return(
        status: 200,
        body: "# Just Content\n\nNo frontmatter here.",
        headers: { "Content-Type" => "text/markdown" }
      )

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/bare-md")

    assert_equal "cloudflare", entry.conversion
    assert_equal "", entry.title
    assert_equal "", entry.description
    assert_includes entry.markdown, "# Just Content"
  end

  def test_cookies_sent_from_netscape_file
    cookie_file = File.join(@test_dir, "cookies.txt")
    File.write(cookie_file, ".example.com\tTRUE\t/\tFALSE\t0\tsession\tabc123\n")

    stub_request(:get, "https://example.com/auth")
      .with(headers: { "Cookie" => /session=abc123/ })
      .to_return(
        status: 200,
        body: "<html><head><title>Auth Page</title></head><body><p>Secret content.</p></body></html>",
        headers: { "Content-Type" => "text/html" }
      )

    fetcher = Mddir::Fetcher.new(@config, cookies_path: cookie_file)
    entry = fetcher.fetch("https://example.com/auth")

    refute_nil entry
    assert_equal "local", entry.conversion
  end

  def test_multiple_cookies_from_netscape_file
    cookie_file = File.join(@test_dir, "cookies.txt")
    cookies_content = <<~TXT
      .example.com\tTRUE\t/\tFALSE\t0\tsession\tabc123
      .example.com\tTRUE\t/\tFALSE\t0\ttoken\txyz789
    TXT
    File.write(cookie_file, cookies_content)

    stub_request(:get, "https://example.com/multi")
      .with(headers: { "Cookie" => /session=abc123/ })
      .to_return(
        status: 200,
        body: "<html><head><title>Page</title></head><body><p>Content.</p></body></html>",
        headers: { "Content-Type" => "text/html" }
      )

    fetcher = Mddir::Fetcher.new(@config, cookies_path: cookie_file)
    entry = fetcher.fetch("https://example.com/multi")

    refute_nil entry
  end

  def test_no_cookies_when_file_missing
    stub_request(:get, "https://example.com/page")
      .with { |req| req.headers["Cookie"].nil? }
      .to_return(
        status: 200,
        body: "<html><head><title>Page</title></head><body><p>Content.</p></body></html>",
        headers: { "Content-Type" => "text/html" }
      )

    fetcher = Mddir::Fetcher.new(@config, cookies_path: "/nonexistent/cookies.txt")
    entry = fetcher.fetch("https://example.com/page")

    refute_nil entry
  end

  def test_code_language_preserved_through_conversion
    html = <<~HTML
      <html>
      <head><title>Code Example</title></head>
      <body>
        <article>
          <h1>Code Example</h1>
          <p>Here is some Ruby code:</p>
          <pre><code class="language-ruby">def hello
        puts "world"
      end</code></pre>
          <p>And some Python:</p>
          <pre><code class="language-python">def hello():
          print("world")</code></pre>
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/code")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/code")

    assert_includes entry.markdown, "```ruby"
    assert_includes entry.markdown, "```python"
  end

  def test_description_extracted_from_meta_tag
    html = <<~HTML
      <html>
      <head>
        <title>Test Page</title>
        <meta name="description" content="A detailed article about testing strategies.">
      </head>
      <body><article><p>Content here.</p></article></body>
      </html>
    HTML

    stub_request(:get, "https://example.com/meta")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/meta")

    assert_equal "A detailed article about testing strategies.", entry.description
  end

  def test_missing_description_returns_empty_string
    html = <<~HTML
      <html>
      <head><title>No Description</title></head>
      <body><article><p>Content without meta description.</p></article></body>
      </html>
    HTML

    stub_request(:get, "https://example.com/no-desc")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/no-desc")

    assert_equal "", entry.description
  end

  def test_output_markdown_is_always_utf8
    html = "<html><head><title>Caf\u00e9</title></head><body><article><p>Content with caf\u00e9 and \u00fc.</p></article></body></html>" # rubocop:disable Layout/LineLength

    stub_request(:get, "https://example.com/utf8")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html; charset=utf-8" })

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/utf8")

    assert_equal Encoding::UTF_8, entry.markdown.encoding
    assert_predicate entry.markdown, :valid_encoding?
  end

  def test_sends_accept_header_for_content_negotiation
    stub_request(:get, "https://example.com/negotiate")
      .with(headers: { "Accept" => "text/markdown, text/html" })
      .to_return(
        status: 200,
        body: "<html><head><title>Page</title></head><body><p>Content.</p></body></html>",
        headers: { "Content-Type" => "text/html" }
      )

    fetcher = Mddir::Fetcher.new(@config)
    fetcher.fetch("https://example.com/negotiate")

    assert_requested :get, "https://example.com/negotiate",
                     headers: { "Accept" => "text/markdown, text/html" }
  end

  def test_sends_configured_user_agent
    stub_request(:get, "https://example.com/ua-test")
      .to_return(
        status: 200,
        body: "<html><head><title>Page</title></head><body><p>Content.</p></body></html>",
        headers: { "Content-Type" => "text/html" }
      )

    fetcher = Mddir::Fetcher.new(@config)
    fetcher.fetch("https://example.com/ua-test")

    assert_requested :get, "https://example.com/ua-test",
                     headers: { "User-Agent" => @config.user_agent }
  end

  def test_local_conversion_estimates_token_count
    html = <<~HTML
      <html>
      <head><title>Token Test</title></head>
      <body><article><p>#{"word " * 100}</p></article></body>
      </html>
    HTML

    stub_request(:get, "https://example.com/tokens")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    fetcher = Mddir::Fetcher.new(@config)
    entry = fetcher.fetch("https://example.com/tokens")

    assert entry.token_estimated
    assert_operator entry.token_count, :>, 0
  end
end
