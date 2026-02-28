# frozen_string_literal: true

require "digest"
require "time"
require "yaml"

module Mddir
  class Entry
    attr_reader :url,
                :title,
                :description,
                :slug,
                :filename,
                :markdown,
                :conversion,
                :token_count,
                :token_estimated,
                :saved_at

    def initialize(url:, title:, description:, markdown:, conversion:, token_count:, token_estimated:) # rubocop:disable Metrics/ParameterLists
      @url = url
      @title = title.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      @description = description.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      @markdown = markdown.encode("UTF-8", invalid: :replace, undef: :replace)
      @conversion = conversion
      @token_count = token_count
      @token_estimated = token_estimated
      @saved_at = Time.now.utc.iso8601
      @slug = generate_slug
      @filename = "#{@slug}.md"
    end

    def to_index_entry
      {
        "url" => @url,
        "title" => @title,
        "description" => @description,
        "filename" => @filename,
        "slug" => @slug,
        "saved_at" => @saved_at,
        "conversion" => @conversion,
        "token_count" => @token_count,
        "token_estimated" => @token_estimated
      }
    end

    def to_markdown_with_frontmatter
      frontmatter = {
        "url" => @url,
        "title" => @title,
        "description" => @description,
        "slug" => @slug,
        "saved_at" => @saved_at,
        "conversion" => @conversion,
        "token_count" => @token_count,
        "token_estimated" => @token_estimated
      }

      content = Utils.strip_frontmatter(@markdown)
      yaml_str = YAML.dump(frontmatter).delete_prefix("---\n").chomp
      "---\n#{yaml_str}\n---\n\n#{content}"
    end

    def save_to(collection_path)
      file_path = File.join(collection_path, @filename)
      File.write(file_path, to_markdown_with_frontmatter)
    end

    private

    def generate_slug
      title_slug = Utils.slugify(@title.empty? ? "untitled" : @title)
      hash = Digest::SHA256.hexdigest(@url)[0, 6]
      "#{title_slug}-#{hash}"
    end
  end
end
