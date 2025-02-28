require "active_record/connection_adapters/abstract_adapter"
require "peasys"

module ActiveRecord
  module ConnectionAdapters
    class PeasysAdapter < AbstractAdapter
      ADAPTER_NAME = "Peasys"

      def initialize(connection, logger = nil, config = {})
        super(connection, logger)
        @client = PeaClient.new(
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

      def self.new_client(config)
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

ActiveRecord::ConnectionAdapters::AbstractAdapter.descendants << ActiveRecord::ConnectionAdapters::PeasysAdapter
ActiveRecord::Base.establish_connection(adapter: 'peasys')
