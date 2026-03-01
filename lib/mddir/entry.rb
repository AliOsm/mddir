# frozen_string_literal: true

require "digest"
require "time"
require "yaml"

module Mddir
  TokenInfo = Struct.new(:count, :estimated) # rubocop:disable Lint/StructNewOverride

  class Entry
    attr_reader :url,
                :title,
                :description,
                :slug,
                :filename,
                :markdown,
                :conversion,
                :token_info,
                :saved_at

    def initialize(url:, title:, description:, markdown:, conversion:, token_info:) # rubocop:disable Metrics/ParameterLists
      @url = url
      @title = title.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      @description = description.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      @markdown = markdown.encode("UTF-8", invalid: :replace, undef: :replace)
      @conversion = conversion
      @token_info = token_info
      @saved_at = Time.now.utc.iso8601
      @slug = generate_slug
      @filename = "#{@slug}.md"
    end

    def to_index_entry
      metadata.merge("filename" => @filename)
    end

    def to_markdown_with_frontmatter
      content = Utils.strip_frontmatter(@markdown)
      "#{YAML.dump(metadata)}---\n\n#{content}"
    end

    def save_to(collection_path)
      file_path = File.join(collection_path, @filename)
      File.write(file_path, to_markdown_with_frontmatter)
    end

    private

    def metadata
      {
        "url" => @url,
        "title" => @title,
        "description" => @description,
        "slug" => @slug,
        "saved_at" => @saved_at,
        "conversion" => @conversion,
        "token_count" => @token_info.count,
        "token_estimated" => @token_info.estimated
      }
    end

    def generate_slug
      title_slug = Utils.slugify(@title.empty? ? "untitled" : @title)
      hash = Digest::SHA256.hexdigest(@url)[0, 6]
      "#{title_slug}-#{hash}"
    end
  end
end
