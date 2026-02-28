# frozen_string_literal: true

module Mddir
  module Utils
    def self.slugify(text)
      text.downcase
          .gsub(/[^a-z0-9]+/, "-")
          .gsub(/-{2,}/, "-")
          .gsub(/\A-|-\z/, "")
    end

    def self.strip_frontmatter(text)
      if text.start_with?("---")
        parts = text.split("---", 3)
        parts.length >= 3 ? parts[2].lstrip : text
      else
        text
      end
    end

    def self.skip_frontmatter(lines) # rubocop:disable Metrics/MethodLength
      result = []
      in_frontmatter = false

      lines.each_with_index do |line, index|
        line_number = index + 1

        if line_number == 1 && line.strip == "---"
          in_frontmatter = true
          next
        end

        if in_frontmatter && line.strip == "---"
          in_frontmatter = false
          next
        end

        next if in_frontmatter

        result << [line_number, line.chomp]
      end

      result
    end
  end
end
