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

    def self.skip_frontmatter(lines)
      start = find_frontmatter_end(lines)

      lines[start..].each_with_index.filter_map do |line, i|
        line_number = start + i + 1
        [line_number, line.chomp]
      end
    end

    def self.find_frontmatter_end(lines)
      return 0 unless lines.first&.strip == "---"

      lines.each_with_index do |line, i|
        next if i.zero?
        return i + 1 if line.strip == "---"
      end

      0
    end

    private_class_method :find_frontmatter_end
  end
end
