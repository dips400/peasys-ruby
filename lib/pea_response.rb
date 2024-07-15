# Abstracts the concept of response in the case of a query executed on the database of an AS/400 server by a PeaClient object.

class PeaResponse

    ##
    # Initialize a new instance of the PeaResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.

    def initialize(has_succeeded, sql_message, sql_state)
        @has_succeeded = has_succeeded
        @sql_message = sql_message
        @sql_state = sql_state
    end

    def has_succeeded
        @has_succeeded
    end

    def sql_message
        @sql_message
    end

    def sql_state
        @sql_state
    end
end

# Represents the concept of response in the case of a CREATE query executed on the database of an AS/400 server by a PeaClient object.

class PeaCreateResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaCreateResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.
    # +database_name+:: Name of the database if the SQL create query creates a new database.
    # +index_name+:: Name of the index if the SQL create query creates a new index.
    # +table_schema+:: Schema of the table if the SQL create query creates a new table. The Schema is a Dictionary with columns' name as key and a ColumnInfo object as value.

    def initialize(has_succeeded, sql_message, sql_state, database_name, index_name, table_schema)
        super has_succeeded, sql_message, sql_state

        @database_name = database_name
        @index_name = index_name
        @table_schema = table_schema
    end

    def database_name
        @database_name
    end

    def index_name
        @index_name
    end

    def table_schema
        @table_schema
    end
end

# Represents the concept of response in the case of an ALTER query executed on the database of an AS/400 server by a PeaClient object.

class PeaAlterResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaAlterResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.
    # +table_schema+:: Schema of the table if the SQL create query creates a new table. The Schema is a Dictionary with columns' name as key and a ColumnInfo object as value.

    def initialize(has_succeeded, sql_message, sql_state, table_schema)
        super has_succeeded, sql_message, sql_state
        
        @table_schema = table_schema
    end

    def table_schema
        @table_schema
    end
end

# Represents the concept of response in the case of a DROP query executed on the database of an AS/400 server by a PeaClient object.

class PeaDropResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaDropResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.

    def initialize(has_succeeded, sql_message, sql_state)
        super has_succeeded, sql_message, sql_state
    end
end

# Represents the concept of response in the case of a SELECT query executed on the database of an AS/400 server by a PeaClient object.

class PeaSelectResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaSelectResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.
    # +result+:: Results of the query in the form of an Dictionary where the columns' name are the key and the values are the elements of this column in the SQL table.
    # +row_count+:: Represents the number of rows that have been retreived by the query.
    # +columns_name+:: Array representing the name of the columns in the order of the SELECT query.
    
    def initialize(has_succeeded, sql_message, sql_state, result, row_count, columns_name)
        super has_succeeded, sql_message, sql_state

        @result = result
        @row_count = row_count
        @columns_name = columns_name
    end

    def result
        @result
    end

    def row_count
        @row_count
    end

    def columns_name
        @columns_name
    end
end

# Represents the concept of response in the case of an UPDATE query executed on the database of an AS/400 server by a PeaClient object.

class PeaUpdateResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.
    # +row_count+:: Represents the number of rows that have been updated by the query.

    def initialize(has_succeeded, sql_message, sql_state, row_count)
        super has_succeeded, sql_message, sql_state
        
        @row_count = row_count
    end

    def row_count
        @row_count
    end
end

# Represents the concept of response in the case of a DELETE query executed on the database of an AS/400 server by a PeaClient object.

class PeaDeleteResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.
    # +row_count+:: Represents the number of rows that have been updated by the query.

    def initialize(has_succeeded, sql_message, sql_state, row_count)
        super has_succeeded, sql_message, sql_state
        
        @row_count = row_count
    end

    def row_count
        @row_count
    end
end

# Represents the concept of response in the case of an INSERT query executed on the database of an AS/400 server by a PeaClient object.

class PeaInsertResponse < PeaResponse

    ##
    # Initialize a new instance of the PeaResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the query has correctly been executed. Set to true if the SQL state is 00000.
    # +sql_message+:: SQL message return from the execution of the query.
    # +sql_state+:: SQL state return from the execution of the query.
    # +row_count+:: Represents the number of rows that have been updated by the query.

    def initialize(has_succeeded, sql_message, sql_state, row_count)
        super has_succeeded, sql_message, sql_state
        
        @row_count = row_count
    end

    def row_count
        @row_count
    end
end

# Represents the concept of response in the case of an OS/400 command executed on the database of an AS/400 server by a PeaClient object.

class PeaCommandResponse

    ##
    # Initialize a new instance of the PeaCommandResponse class.
    #
    # Params:
    # +has_succeeded+:: Boolean set to true if the command has correctly been executed meaning that no CPFxxxx was return. Still, description messages can be return along with CP*xxxx.
    # +warnings+:: List of warnings that results form the command execution. Errors are of the form : CP*xxxx Description of the warning. 

    def initialize(has_succeeded, warnings)
        @has_succeeded = has_succeeded
        @warnings = warnings
    end

    def has_succeeded
        @has_succeeded
    end

    def warnings
        @warnings
    end
end

# Represents the concept of metadata for a column of an SQL table on the AS/400 server.
class ColumnInfo

    ##
    # Initialize a new instance of the ColumnInfo class.
    #
    # Params:
    # +column_name+:: Name of the column.
    # +ordinal_position+:: Ordinal position of the column.
    # +data_type+:: DB2 Type of the data contain in the column.
    # +length+:: Length of the data contain in the column.
    # +numeric_scale+:: Scale of the data contain in the column if numeric type.
    # +is_nullable+:: Y/N depending on the nullability of the field.
    # +is_updatable+:: Y/N depending on the updaptability of the field.
    # +numeric_precision+:: Precision of the data contain in the column if numeric type.

    def initialize(column_name, ordinal_position, data_type, length, numeric_scale, is_nullable, is_updatable, numeric_precision)
        @column_name = column_name
        @ordinal_position = ordinal_position
        @data_type = data_type
        @length = length
        @numeric_scale = numeric_scale
        @numeric_precision = numeric_precision
        @is_nullable = is_nullable
        @is_updatable = is_updatable
        @numeric_precision = numeric_precision
    end
    
    def column_name
        @column_name
    end

    def ordinal_position
        @ordinal_position
    end

    def data_type
        @data_type
    end

    def length
        @length
    end

    def numeric_scale
        @numeric_scale
    end

    def numeric_precision
        @numeric_precision
    end

    def is_nullable
        @is_nullable
    end

    def is_updatable
        @is_updatable
    end

    def numeric_precision
        @numeric_precision
    end
end