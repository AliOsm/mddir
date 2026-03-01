# frozen_string_literal: true

require "http-cookie"
require "httpx"
require "nokogiri"
require "readability"
require "reverse_markdown"
require "yaml"

module Mddir
  class Fetcher # rubocop:disable Metrics/ClassLength
    CONNECT_TIMEOUT = 15
    READ_TIMEOUT = 30

    READABILITY_TAGS = %w[
      div p span
      h1 h2 h3 h4 h5 h6
      pre code
      ul ol li
      table thead tbody tfoot tr th td
      blockquote
      a img br hr
      strong em b i u s del sub sup
      dl dt dd
      figure figcaption
      details summary
    ].freeze

    READABILITY_ATTRIBUTES = %w[href src alt title lang class id style].freeze

    def initialize(config, cookies_path: nil)
      @config = config
      @cookie_jar = load_cookies(cookies_path)
      @client = build_client
    end

    def fetch(url)
      response = request(url)
      content_type = response.headers["content-type"].to_s

      if content_type.include?("text/markdown")
        process_markdown_response(url, response)
      else
        process_html_response(url, response)
      end
    end

    private

    def load_cookies(path)
      return nil unless path && File.exist?(path)

      jar = HTTP::CookieJar.new
      jar.load(path, format: :cookiestxt, session: true)
      jar
    end

    def build_client
      HTTPX.plugin(:follow_redirects)
           .with(
             headers: {
               "accept" => "text/markdown, text/html",
               "user-agent" => @config.user_agent
             },
             timeout: { connect_timeout: CONNECT_TIMEOUT, read_timeout: READ_TIMEOUT }
           )
    end

    def request(url)
      headers = cookie_headers(url)
      response = @client.get(url, headers: headers)
      raise FetchError, response.error.message if response.is_a?(HTTPX::ErrorResponse)

      response
    end

    def cookie_headers(url)
      return {} unless @cookie_jar

      uri = URI.parse(url)
      cookie_value = HTTP::Cookie.cookie_value(@cookie_jar.cookies(uri))
      cookie_value.empty? ? {} : { "cookie" => cookie_value }
    end

    def normalize_encoding(body, content_type)
      body = body.dup
      charset = content_type&.match(/charset=([^\s;]+)/i)&.captures&.first # rubocop:disable Style/SafeNavigationChainLength
      body.force_encoding(charset || "UTF-8")
      body.encode("UTF-8", invalid: :replace, undef: :replace)
    end

    def process_markdown_response(url, response)
      body = normalize_encoding(response.body.to_s, response.headers["content-type"])
      frontmatter, content = parse_frontmatter(body)
      token_count, token_estimated = resolve_token_count(content, response.headers["x-markdown-tokens"])

      Entry.new(
        url:,
        title: frontmatter["title"].to_s,
        description: frontmatter["description"].to_s,
        markdown: body,
        conversion: "cloudflare",
        token_count:,
        token_estimated:
      )
    end

    def parse_frontmatter(body)
      if body.start_with?("---")
        parts = body.split("---", 3)
        if parts.length >= 3
          frontmatter = YAML.safe_load(parts[1], permitted_classes: [Time]) || {}
          return [frontmatter, parts[2].lstrip]
        end
      end

      [{}, body]
    end

    def resolve_token_count(content, header)
      if header
        [header.to_i, false]
      else
        [(content.length / 4.0).ceil, true]
      end
    end

    def process_html_response(url, response)
      html = normalize_encoding(response.body.to_s, response.headers["content-type"])
      document = Nokogiri::HTML(html)
      simplify_image_markup(document)
      title, article_html = extract_readable_content(document.to_html, document)
      markdown = html_to_markdown(article_html)

      Entry.new(
        url:,
        title:,
        description: extract_description(document),
        markdown:,
        conversion: "local",
        token_count: (markdown.length / 4.0).ceil,
        token_estimated: true
      )
    end

    def simplify_image_markup(document)
      document.css("picture").each do |picture|
        img = picture.at("img")
        img ? picture.replace(img) : picture.remove
      end

      document.css("a").each do |a|
        img = a.at("img")
        next unless img

        a.replace(img) if a.text.strip.empty?
      end
    end

    def extract_readable_content(html, document)
      title, article_html = run_readability(html)

      if article_html.nil? || article_html.strip.empty?
        warn "Warning: readability extracted no content, falling back to full body"
        article_html = document.at("body")&.inner_html.to_s
      end

      title = extract_title(document) if title.empty?

      [clean_title(title), article_html]
    end

    def run_readability(html)
      readable = Readability::Document.new(html, tags: READABILITY_TAGS, attributes: READABILITY_ATTRIBUTES)
      [readable.title.to_s, readable.content]
    rescue StandardError
      ["", nil]
    end

    def html_to_markdown(article_html)
      article_html = article_html.encode("UTF-8", invalid: :replace, undef: :replace)
      code_languages = extract_code_languages(article_html)
      markdown = ReverseMarkdown.convert(article_html, github_flavored: true).force_encoding("UTF-8")
      inject_code_languages(markdown, code_languages)
    end

    def extract_code_languages(html) # rubocop:disable Metrics/CyclomaticComplexity
      fragment = Nokogiri::HTML.fragment(html)

      fragment.css("pre").map do |pre|
        pre["lang"] ||
          pre["data-lang"] ||
          pre.css("code").first&.[]("class")&.match(/language-(\w+)/)&.captures&.first # rubocop:disable Style/SafeNavigationChainLength
      end
    end

    def inject_code_languages(markdown, languages) # rubocop:disable Metrics/MethodLength
      index = 0

      markdown.gsub(/^```\s*$/) do |match|
        if index.even? && (index / 2) < languages.length
          lang = languages[index / 2]
          index += 1
          lang ? "```#{lang}" : match
        else
          index += 1
          match
        end
      end
    end

    def extract_description(document)
      meta = document.at('meta[name="description"]')
      meta ? meta["content"].to_s : ""
    end

    def extract_title(document)
      title_tag = document.at("title")
      title_tag ? title_tag.text.to_s.strip : ""
    end

    def clean_title(title)
      title.sub(/\s*[|–—-]\s*[^|–—-]+\z/, "").strip
    end
  end

  class FetchError < StandardError; end
end
