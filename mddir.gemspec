# frozen_string_literal: true

require_relative "lib/mddir/version"

Gem::Specification.new do |spec|
  spec.name = "mddir"
  spec.version = Mddir::VERSION
  spec.authors = ["Ali Hamdi Ali Fadel"]
  spec.email = ["aliosm1997@gmail.com"]

  spec.summary = "Local personal knowledge base — save web pages as markdown"
  spec.description = "A CLI tool that fetches web pages, converts them to markdown, " \
                     "and organizes them into local collections. Includes a built-in " \
                     "web UI for browsing and reading saved content."
  spec.homepage = "https://github.com/AliOsm/mddir"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/AliOsm/mddir"
  spec.metadata["changelog_uri"] = "https://github.com/AliOsm/mddir/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "views/**/*", "public/**/*", "exe/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = ["mddir"]
  spec.require_paths = ["lib"]

  spec.add_dependency "http-cookie", "~> 1.0"
  spec.add_dependency "httpx", "~> 1.7"
  spec.add_dependency "kramdown", "~> 2.5", ">= 2.5.2"
  spec.add_dependency "kramdown-parser-gfm", "~> 1.1"
  spec.add_dependency "nokogiri", "~> 1.19", ">= 1.19.1"
  spec.add_dependency "puma", "~> 7.2"
  spec.add_dependency "rackup", "~> 2.3", ">= 2.3.1"
  spec.add_dependency "reverse_markdown", "~> 3.0", ">= 3.0.2"
  spec.add_dependency "rouge", "~> 4.7"
  spec.add_dependency "ruby-readability", "~> 0.7.3"
  spec.add_dependency "sinatra", "~> 4.2", ">= 4.2.1"
  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "thor", "~> 1.5"
end
