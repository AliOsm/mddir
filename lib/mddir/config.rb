# frozen_string_literal: true

require "yaml"

module Mddir
  class Config
    DEFAULT_PATH = File.expand_path("~/.mddir.yml")

    DEFAULTS = {
      "base_dir" => "~/.mddir",
      "port" => 7768,
      "editor" => ENV.fetch("EDITOR", "vi"),
      "user_agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" # rubocop:disable Layout/LineLength
    }.freeze

    attr_reader :path

    def initialize(path: DEFAULT_PATH)
      @path = path
      @data = DEFAULTS.dup
      load_config if File.exist?(path)
    end

    def base_dir
      File.expand_path(@data["base_dir"])
    end

    def port
      @data["port"].to_i
    end

    def editor
      @data["editor"]
    end

    def user_agent
      @data["user_agent"]
    end

    def create_default_config!
      return if File.exist?(path)

      File.write(path, YAML.dump(DEFAULTS))
    end

    private

    def load_config
      loaded = YAML.safe_load_file(path)
      @data.merge!(loaded) if loaded.is_a?(Hash)
    rescue Psych::SyntaxError
      # Use defaults if config is corrupted
    end
  end
end
