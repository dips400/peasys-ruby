begin
    require 'active_record/connection_adapters/abstract_adapter'
  
    module ActiveRecord
      module ConnectionHandling
        def peasys_connection(config)
          require 'peasys-ruby'



          if true

            PeaClient.new(config[:ip_address],config[:partition_name],config[:port],config[:username],config[:password],config[:id_client],config[:online_version],config[:retrieve_statistics])
          end


        end
      end
    end
  rescue LoadError
  end  