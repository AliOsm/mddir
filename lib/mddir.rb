# frozen_string_literal: true

require_relative "mddir/version"
require_relative "mddir/utils"
require_relative "mddir/config"
require_relative "mddir/global_index"
require_relative "mddir/collection"
require_relative "mddir/entry"
require_relative "mddir/fetcher"
require_relative "mddir/search_index"
require_relative "mddir/search"
require_relative "mddir/cli"

module Mddir
  class Error < StandardError; end
end
