require_relative "../lib/active_record/connection_adapters/peasys_adapter"

ActiveRecord::ConnectionAdapters::AbstractAdapter.descendants << ActiveRecord::ConnectionAdapters::PeasysAdapter