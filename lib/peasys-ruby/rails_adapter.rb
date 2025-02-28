begin
    require 'active_record/connection_adapters/abstract_adapter'
  
    module ActiveRecord
      module ConnectionHandling
        def peasys_connection(config)
          require 'peasys-ruby'
  
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
  rescue LoadError
  end  