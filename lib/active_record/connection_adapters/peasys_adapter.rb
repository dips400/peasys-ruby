require "active_record/connection_adapters/abstract_adapter"
require "peasys" # Charge la gem peasys-ruby

module ActiveRecord
  module ConnectionAdapters
    class PeasysAdapter < AbstractAdapter
      def initialize(connection, logger = nil)
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

      # Ouvre la connexion
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

      # Exécute une requête SQL
      def execute(sql, name = nil)
        log(sql, name) do
          @client.query(sql)
        end
      end

      # Vérifie si la connexion est active
      def active?
        @client.connected == "Connected"
      end

      # Ferme la connexion proprement
      def disconnect!
        @client.close
      end

      # Relance la connexion
      def reconnect!
        disconnect!
        @client = self.class.new_client(@config)
      end

      # Support des transactions
      def begin_db_transaction
        execute("BEGIN")
      end

      def commit_db_transaction
        execute("COMMIT")
      end

      def rollback_db_transaction
        execute("ROLLBACK")
      end
    end
  end
end
ActiveRecord::ConnectionAdapters::AbstractAdapter.descendants << ActiveRecord::ConnectionAdapters::PeasysAdapter

# Enregistrer l'adaptateur sous le nom "peasys"
ActiveRecord::ConnectionAdapters::POOLABLE_CONNECTION_TYPES[:peasys] = ActiveRecord::ConnectionAdapters::PeasysAdapter