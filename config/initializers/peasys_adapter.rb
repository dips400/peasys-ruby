require 'active_record/connection_adapters/abstract_adapter'
require 'peasys'
ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/peasys_adapter"
end

module ActiveRecord
  module ConnectionHandling
    def peasys_connection(config)
      PeaClient.new(
        ip_address: config["ip_address"],
        partition_name: config["partition_name"],
        port: config["port"],
        username: config["username"],
        password: config["password"],
        id_client: config["id_client"],
        online_version: config["online_version"],
        retrieve_statistics: config["retrieve_statistics"]
      )
    end
  end
end