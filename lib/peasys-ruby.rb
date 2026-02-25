require_relative "pea_client"
require_relative "pea_exception"
require_relative "pea_response"

module PeasysRuby
  VERSION = "2.0.0"
end

if defined?(ActiveRecord)
  require "active_record/connection_adapters/peasys_adapter"
end
