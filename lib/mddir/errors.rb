# frozen_string_literal: true

module Mddir
  class Error < StandardError; end

  class FetchError < Error; end
  class CorruptIndexError < Error; end
  class SearchError < Error; end
end
