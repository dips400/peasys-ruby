require "active_record/connection_adapters/abstract_adapter"
require "peasys" # Charge la gem peasys-ruby

module ActiveRecord
  module ConnectionAdapters
    class PeasysAdapter < AbstractAdapter
      def initialize(connection, logger = nil, config = {})
        super(connection, logger)

        @config = config.symbolize_keys
        @client = PeaClient.new(
          @config[:ip_address],
          @config[:partition_name],
          @config[:port],
          @config[:username],
          @config[:password],
          @config[:id_client],
          @config[:online_version],
          @config[:retrieve_statistics]
        )
      end

      def self.new_client(config)
        config = config.symbolize_keys
        PeaClient.new(
          config[:ip_address],
          config[:partition_name],
          config[:port],
          config[:username],
          config[:password],
          config[:id_client],
          config[:online_version],
          config[:retrieve_statistics]
        )
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::POOLABLE_CONNECTION_TYPES[:peasys] = ActiveRecord::ConnectionAdapters::PeasysAdapter
