# frozen_string_literal: true

require "test_helper"
require "mddir/fetcher"

class TestFetcher < Minitest::Test # rubocop:disable Metrics/ClassLength
  # Readability needs sufficient surrounding text density to keep article content,
  # so image tests use ARTICLE_PADDING to simulate realistic pages.
  ARTICLE_PADDING = <<~HTML
    <p>This is a substantial paragraph of text that discusses various topics related to the article.
    It needs to be long enough for the readability algorithm to consider this section worthy of extraction.</p>
    <p>Here is another paragraph with additional context and detail so the content extractor treats this
    as a real article rather than boilerplate navigation or footer text that should be stripped out.</p>
  HTML

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

  def test_image_inside_picture_element_preserved
    html = <<~HTML
      <html>
      <head><title>Image Test</title></head>
      <body>
        <article>
          #{ARTICLE_PADDING}
          <figure>
            <picture>
              <source type="image/webp" srcset="https://cdn.example.com/photo.webp">
              <img src="https://cdn.example.com/photo.png" alt="A photo">
            </picture>
          </figure>
          #{ARTICLE_PADDING}
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/picture")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    entry = Mddir::Fetcher.new(@config).fetch("https://example.com/picture")

    assert_includes entry.markdown, "![A photo](https://cdn.example.com/photo.png)"
  end

  def test_image_inside_linked_picture_substack_style
    html = <<~HTML
      <html>
      <head><title>Substack Post</title></head>
      <body>
        <article>
          #{ARTICLE_PADDING}
          <figure>
            <div class="captioned-image-container">
              <a class="image-link" href="https://cdn.example.com/full.png">
                <div class="image2-inset">
                  <picture>
                    <source type="image/webp" srcset="https://cdn.example.com/photo.webp">
                    <img src="https://cdn.example.com/photo.png" alt="" sizes="100vw">
                  </picture>
                </div>
              </a>
            </div>
          </figure>
          #{ARTICLE_PADDING}
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/substack")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    entry = Mddir::Fetcher.new(@config).fetch("https://example.com/substack")

    assert_includes entry.markdown, "![](https://cdn.example.com/photo.png)"
    refute_match(/(?<!!)\[\s*\]\(/, entry.markdown, "should not produce empty link syntax")
  end

  def test_plain_img_tag_unchanged
    html = <<~HTML
      <html>
      <head><title>Plain Image</title></head>
      <body>
        <article>
          #{ARTICLE_PADDING}
          <img src="https://cdn.example.com/photo.png" alt="Plain image">
          #{ARTICLE_PADDING}
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/plain-img")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    entry = Mddir::Fetcher.new(@config).fetch("https://example.com/plain-img")

    assert_includes entry.markdown, "![Plain image](https://cdn.example.com/photo.png)"
  end

  def test_linked_image_with_text_preserves_link
    html = <<~HTML
      <html>
      <head><title>Linked Image</title></head>
      <body>
        <article>
          #{ARTICLE_PADDING}
          <a href="https://example.com/article">
            <img src="https://cdn.example.com/thumb.png" alt="Thumbnail">
            Click for more
          </a>
          #{ARTICLE_PADDING}
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/linked-img")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    entry = Mddir::Fetcher.new(@config).fetch("https://example.com/linked-img")

    assert_includes entry.markdown, "https://example.com/article"
    assert_includes entry.markdown, "Click for more"
  end

  def test_picture_without_img_removed_cleanly
    html = <<~HTML
      <html>
      <head><title>Empty Picture</title></head>
      <body>
        <article>
          #{ARTICLE_PADDING}
          <picture>
            <source type="image/webp" srcset="https://cdn.example.com/photo.webp">
          </picture>
          #{ARTICLE_PADDING}
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/empty-picture")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    entry = Mddir::Fetcher.new(@config).fetch("https://example.com/empty-picture")

    refute_includes entry.markdown, "<picture>"
    refute_includes entry.markdown, "<source>"
  end

  def test_multiple_images_all_preserved
    html = <<~HTML
      <html>
      <head><title>Gallery</title></head>
      <body>
        <article>
          #{ARTICLE_PADDING}
          <figure>
            <picture>
              <img src="https://cdn.example.com/one.png" alt="First">
            </picture>
          </figure>
          <figure>
            <picture>
              <img src="https://cdn.example.com/two.png" alt="Second">
            </picture>
          </figure>
          #{ARTICLE_PADDING}
        </article>
      </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/gallery")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    entry = Mddir::Fetcher.new(@config).fetch("https://example.com/gallery")

    assert_includes entry.markdown, "![First](https://cdn.example.com/one.png)"
    assert_includes entry.markdown, "![Second](https://cdn.example.com/two.png)"
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
