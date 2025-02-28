require_relative "../lib/active_record/connection_adapters/peasys_adapter"
require 'dotenv/load' if Rails.env.development? || Rails.env.test?


ActiveRecord::ConnectionAdapters::AbstractAdapter.descendants << ActiveRecord::ConnectionAdapters::PeasysAdapter