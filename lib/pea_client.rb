require 'socket'
require 'json'
require 'uri'
require 'net/http'
require 'peasys-ruby/rails_adapter' if defined?(Rails)


class PeaClient
    if defined?(ActiveRecord)
        attr_accessor :pool
        attr_accessor :leased
        attr_accessor :lock_thread
        attr_accessor :last_used_time
    end
    def pool=(value)
        @pool = value
    end
    
    def pool
        @pool
    end
    @@end_pack = "dipsjbiemg"

    def check_version
        true
    end

    def lease
        @leased = true
    end

    def in_use?
        @in_use
    end

    def seconds_idle
        Time.now - @last_used_time
    end

    def mark_as_used
        @in_use = true
        @last_used_time = Time.now
    end

    def mark_as_unused
        @in_use = false
    end

    def alive?
        @connexion_message == "Connected"
    end

    def remove_connection_from_thread_cache(conn, owner_thread = conn.owner)
        if owner_thread == Thread.current
          @leased = false
          @owner = nil
        end
    end

    def _run_checkout_callbacks
        yield if block_given?
    end

    def clean!
        @disconnect
        @leased = false
        @owner = nil
    end

    ##
    # Initialize a new instance of the PeaClient class. Initiates a connexion with the AS/400 server.
    #
    # Params:
    # +partition_name+:: DNS name (name of the partition) of the remote AS/400 server.
    # +port+:: Port used for the data exchange between the client and the server.
    # +username+:: Username of the AS/400 profile used for connexion.
    # +password+:: Password of the AS/400 profile used for connexion.
    # +id_client+:: ID of the client account on the DIPS website.
    # +online_version+:: Set to true if you want to use the online version of Peasys (<see cref="https://dips400.com/docs/connexion"/>).
    # +retrieve_statistics+:: Set to true if you want the statistics of the license key use to be collect.
    #
    # raises a PeaInvalidCredentialsError if credentials are empty.
    # raises a PeaConnexionError if an error occured during the connexion process.
    # raises a PeaInvalidCredentialsError if IBMi credentials are invalid.

    def initialize(ip_adress, partition_name, port, username, password, id_client, online_version, retrieve_statistics)

        if ip_adress.empty? || username.empty? || password.empty?
            raise PeaInvalidCredentialsError.new("Parameters of the PeaClient should not be either null or empty")
        end

        @ip_adress = ip_adress
        @id_client = id_client
        @partition_name = partition_name
        @username = username
        @password = password
        @port = port
        @online_version = online_version
        @retrieve_statistics = retrieve_statistics
        @connexion_status = "ds"
        @connexion_message = "ds"
        @owner = @connexion_message == "Connected"
        @lock_thread = false
        @last_used_time = Time.now
        @in_use = false

        @pool = nil

        token = "xqdsg27010wmca6052009050000000IDSP1tiupozxreybjhlk"
        if online_version
            begin
                uri = URI("https://dips400.com/api/license-key/retrieve-token/#{partition_name}/#{id_client}")
                res = Net::HTTP.get_response(uri)

                data = JSON.parse(res.body)
                token = data["token"]
                is_valid = data["isValid"]

                if not(is_valid)
                    raise PeaInvalidLicenseKeyError.new("Your subscription is not valid, visit https://dips400.com/account/subscriptions for more information.")
                end

            rescue PeaInvalidLicenseKeyError => e
                raise e
            rescue StandardError => error
                # If dips400.com doesn't respond, let's try an affline verification with the offline token
            end
        end
        
        begin
            @tcp_client = TCPSocket.new ip_adress, port
        rescue => error
            raise PeaConnexionError.new(error.full_message)
        else
            login = username.ljust(10, " ") + token.ljust(50, " ") + password
            @tcp_client.send(login, 0)
            @connexion_status = @tcp_client.read(1)

            case @connexion_status
            when "1"
                @connexion_message = "Connected"
                @connexion_status = 1
                @leased = true
            when "2"
                @connexion_message = "Unable to set profile, check profile validity."
                @connexion_status = 2
                raise PeaConnexionError.new("Unable to set profile, check profile validity.")
            when "3"
                @connexion_message = "Invalid credential"
                @connexion_status = 1
                raise PeaInvalidCredentialsError.new("Invalid userName or password, check again")
            when "B"
                @connexion_message = "Peasys Online : your token connexion is no longer valid, retry to connect."
                @connexion_status = 5
                raise PeaConnexionError.new("Peasys Online : your token connexion is no longer valid, retry to connect.")
            when "D"
                @connexion_message = "Peasys Online : the partition name you provided doesn't match the actual name of the machine."
                @connexion_status = 6
                raise PeaConnexionError.new("Peasys Online : the partition name you provided doesn't match the actual name of the machine.")
            when "E"
                @connexion_message = "You reached the max number of simultaneously connected peasys users for that partition and license key. Contact us for upgrading your license."
                @connexion_status = 7
                raise PeaConnexionError.new("You reached the max number of simultaneously connected peasys users for that partition and license key. Contact us for upgrading your license.")
            when "F"
                @connexion_message = "Your license is no longer valid. Subscribe to another license in order to continue using Peasys."
                @connexion_status = 8
                raise PeaConnexionError.new("Your license is no longer valid. Subscribe to another license in order to continue using Peasys.")
            when "0" , "A" , "C" , "G"
                @connexion_message = "Error linked to DIPS source code. Please, contact us immediatly to fix the issue."
                @connexion_status = -1
                raise PeaConnexionError.new("Error linked to DIPS source code. Please, contact us immediatly to fix the issue.")
            else
                raise PeaConnexionError.new("Exception during connexion process, contact us for more informations")
            end
        end
    end

    ##
    # Sends the SELECT SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the SELECT keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with SELECT.

    def execute_select(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("SELECT")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the SELECT SQL keyword")
        end

        result, list_name, nb_row, sql_state, sql_message = build_data(query)
        
        return PeaSelectResponse.new(sql_message.eql?("00000"), sql_message, sql_state, result, nb_row, list_name)
    end

    ##
    # Sends the UPDATE SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the UPDATE keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with UPDATE.

    def execute_update(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("UPDATE")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the UPDATE SQL keyword")
        end

        nb_row, sql_state, sql_message = modify_table(query)
        has_succeeded = sql_state.eql?("00000") || sql_state.eql?("01504")
        
        return PeaUpdateResponse.new(has_succeeded, sql_message, sql_state, nb_row)
    end

    ##
    # Sends the CREATE SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the CREATE keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with CREATE.

    def execute_create(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("CREATE")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the CREATE SQL keyword")
        end

        nb_row, sql_state, sql_message = modify_table(query)

        query_words = query.split(' ')
        tb_schema = Hash.new()
        if query_words[1].upcase.eql?("TABLE") 
            names = query_words[2].split('/')
            tb_query = """SELECT COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, LENGTH, NUMERIC_SCALE, IS_NULLABLE, IS_UPDATABLE, NUMERIC_PRECISION FROM 
            QSYS2.SYSCOLUMNS WHERE SYSTEM_TABLE_NAME = '""" + names[1].upcase + "' AND SYSTEM_TABLE_SCHEMA = '" + names[0].upcase + "'"

            result, list_name, nb_row, sql_state, sql_message = build_data(tb_query)

            for i in 0..(nb_row - 1) do
                tb_schema["column_name"] = ColumnInfo.new(result["COLUMN_NAME"][i], result["ORDINAL_POSITION"][i], result["DATA_TYPE"][i], result["LENGTH"][i], 
                    result["NUMERIC_SCALE"][i], result["IS_NULLABLE"][i], result["IS_UPDATABLE"][i], result["NUMERIC_PRECISION"][i])
            end
        end

        case query_words[1].upcase
        when "TABLE"
            return PeaCreateResponse.new(sql_message.eql?("00000"), sql_message, sql_state, "", "", tb_schema)
        when "INDEX"
            return PeaCreateResponse.new(sql_message.eql?("00000"), sql_message, sql_state, "", query_words[2], "")
        when "DATABASE"
            return PeaCreateResponse.new(sql_message.eql?("00000"), sql_message, sql_state, query_words[2], "", "")
        else
            raise PeaConnexionError.new("Exception during connexion process, contact us for more informations")
        end
    end
    
    ##
    # Sends the DELETE SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the DELETE keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with DELETE.

    def execute_delete(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("DELETE")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the DELETE SQL keyword")
        end

        nb_row, sql_state, sql_message = modify_table(query)
        
        return PeaDeleteResponse.new(sql_message.eql?("00000"), sql_message, sql_state, nb_row)
    end
    
    ##
    # Sends the ALTER SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the ALTER keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with ALTER.

    def execute_alter(query, retrieve_table_schema)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("ALTER")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the ALTER SQL keyword")
        end

        nb_row, sql_state, sql_message = modify_table(query)

        tb_schema = Hash.new()
        if retrieve_table_schema
            query_words = query.split(' ')
            names = query_words[2].split('/')
            tb_query = """SELECT COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE, LENGTH, NUMERIC_SCALE, IS_NULLABLE, IS_UPDATABLE, NUMERIC_PRECISION FROM 
            QSYS2.SYSCOLUMNS WHERE SYSTEM_TABLE_NAME = '""" + names[1].upcase + "' AND SYSTEM_TABLE_SCHEMA = '" + names[0].upcase + "'"

            result, list_name, nb_row, sql_state, sql_message = build_data(tb_query)

            for i in 0..(nb_row - 1) do
                tb_schema["column_name"] = ColumnInfo.new(result["COLUMN_NAME"][i], result["ORDINAL_POSITION"][i], result["DATA_TYPE"][i], result["LENGTH"][i], 
                    result["NUMERIC_SCALE"][i], result["IS_NULLABLE"][i], result["IS_UPDATABLE"][i], result["NUMERIC_PRECISION"][i])
            end
        end
        
        return PeaAlterResponse.new(sql_message.eql?("00000"), sql_message, sql_state, tb_schema)
    end

    ##
    # Sends the DROP SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the DROP keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with DROP.

    def execute_drop(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("DROP")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the DROP SQL keyword")
        end

        nb_row, sql_state, sql_message = modify_table(query)
        
        return PeaDropResponse.new(sql_message.eql?("00000"), sql_message, sql_state)
    end

    ##
    # Sends the INSERT SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query that should start with the INSERT keyword.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty or doesn't start with INSERT.

    def execute_insert(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end
        if !query.upcase.start_with?("INSERT")
            raise PeaInvalidSyntaxQueryError.new("Query should start with the INSERT SQL keyword")
        end

        nb_row, sql_state, sql_message = modify_table(query)
        
        return PeaInsertResponse.new(sql_message.eql?("00000"), sql_message, sql_state, nb_row)
    end

    ##
    # Sends the SQL query to the server that execute it and retrieve the desired data.
    #
    # Params:
    # +query+:: SQL query.
    #
    # raises a PeaInvalidSyntaxQueryError if query is empty.

    def execute_sql(query)
        if query.empty?
            raise PeaInvalidSyntaxQueryError.new("Query should not be either null or empty")
        end

        nb_row, sql_state, sql_message = modify_table(query)
        
        return PeaResponse.new(sql_message.eql?("00000"), sql_message, sql_state)
    end

    ##
    # Sends a OS/400 command to the server and retreives the potential warning messages.
    #
    # Params:
    # +command+:: The command that will be sent to the server.

    def execute_command(command)
        data = retrieve_data("exas" + command + @@end_pack)
        description_offset = 112
        result = Array.new()

        /C[A-Z]{2}[0-9]{4}/.match(data) do |m|
            
            if !m[0].start_with?("CPI") && m.offset(0)[0] + description_offset < data.length
                description = data[m.offset(0)[0] + description_offset..(data.length - (m.offset(0)[0] + description_offset))]
                description = description[0..description.index(".")]
                description = description.gsub(/[^a-zA-Z0-9 ._'*:-]/, '')
            end

            result.append(m[0] + " " + description)

        end
        return PeaCommandResponse.new(result)
    end

    ##
    # Closes the TCP connexion with the server.

    def disconnect!
        @tcp_client.send("stopdipsjbiemg", 0)
        @tcp_client.close()
        puts "Disconnected"
    end

    def id_client
        @id_client
    end

    def  partition_name
        @partition_name
    end

    def username
        @username
    end

    def port
        @port
    end

    def online_version
        @online_version
    end

    def retrieve_statistics
        @retrieve_statistics
    end

    def connexion_status
        @connexion_status
    end

    def connexion_message
        @connexion_message
    end

    private
    
    def build_data(query)
        header = retrieve_data("geth" + query + @@end_pack)
        sql_state = "00000"
        sql_message = "SELECT correctly executed"

        begin
            header_data = JSON.parse(header)
        rescue
            sql_state = header[1..5];
            sql_message = header[6..];
        else
            list_name = Array.new()
            list_type = Array.new()
            list_prec = Array.new()
            list_scal = Array.new();
        
            header_data.each do |item|
                list_name = list_name.append(item["name"].strip)
                list_type = list_type.append(item["type"].to_i)
                list_prec = list_prec.append(item["prec"].to_i)
                list_scal = list_scal.append(item["scal"].to_i)
            end
        end

        nb_col = list_name.length
        sum_precision = 0
        result = Hash.new()
        list_prec.each_index do |i|
            sum_precision += list_prec[i]
            result[list_name[i]] = Array.new()
        end

        data = retrieve_data("getd" + query + @@end_pack)

        # sends statistics

        nb_row = data.length / sum_precision;
        pointer = 0;
        while pointer != data.length
            for m in 0..(nb_col - 1) do
                scale = list_scal[m]
                precision = list_prec[m]
                type = list_type[m]
                name = list_name[m]
                
                if ((type == 484 && scale != 0) || (type == 485 && scale != 0) || (type == 488 && scale != 0) || (type == 489 && scale != 0)) # numeric packed
                    temp_float_data = data[pointer..(pointer + precision - 1)].to_f / 10 ** scale
                    pointer += precision;
                    result[name].append(temp_float_data.to_s);
                elsif (type == 492 || type == 493) # long
                    result[name].append(data[pointer..(pointer + 20 - 1)].strip);
                    pointer += 20;
                elsif (type == 496 || type == 497) # int
                    result[name].append(data[pointer..(pointer + 10 - 1)].strip);
                    pointer += 10;
                elsif (type == 500 || type == 501) # short
                    result[name].append(data[pointer..(pointer + 5 - 1)].strip);
                    pointer += 5;
                else # string, date, time, timestamp
                    result[name].append(data[pointer..(pointer + precision - 1)].strip);
                    pointer += precision;
                end
            end
        end
        return result, list_name, nb_row, sql_state, sql_message
    end

    def modify_table(query)
        header = retrieve_data("updt" + query + @@end_pack)
        sql_state = header[1..5]
        sql_message = header[6..]

        # retrieve stats

        row_count = 0
        if query.upcase.start_with?("INSERT") || query.upcase.start_with?("UPDATE") || query.upcase.start_with?("DELETE")
            row_count = sql_state.eql?("00000") ? sql_message[..1].to_i : 0
        end

        return row_count, sql_state, sql_message 
    end
    
    def retrieve_data(command)
        
        @tcp_client.send(command, 0)

        data = ""
        if command.start_with?("geth") || command.start_with?("updt")
            data += "["
        end

        while data.length < @@end_pack.length || data[(data.length - @@end_pack.length)..(data.length-1)] != @@end_pack
            data += @tcp_client.read(1)
        end
        return data[0..(data.length - (@@end_pack.length + 1))]
    end
end