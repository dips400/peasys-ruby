require "active_record/connection_adapters/abstract_adapter"
require "peasys-ruby"

module ActiveRecord
  module ConnectionAdapters
    class PeasysAdapter < AbstractAdapter
      attr_reader :pool
      attr_reader :disconnect
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
        @pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(self)
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

      def disconnect!
        @client.disconnect if active?(:disconnect)
      end

      def active?
        @client.connected == "Connected"
      end
      
      def select(sql, name = nil, binds = [])
        puts "PeasysAdapter#select - Executing: #{sql}"  # Debugging
        @client.execute_select(sql)
      end

    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.descendants << ActiveRecord::ConnectionAdapters::PeasysAdapter
ActiveRecord::Base.establish_connection(adapter: 'peasys')
