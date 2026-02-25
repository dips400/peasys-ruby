# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Peasys
      module SchemaStatements
        def tables
          schema = @config[:schema]&.upcase
          sql = <<~SQL
            SELECT TABLE_NAME
            FROM QSYS2.SYSTABLES
            WHERE TABLE_SCHEMA = '#{schema}'
              AND TABLE_TYPE = 'T'
            ORDER BY TABLE_NAME
          SQL
          query_values(sql, "SCHEMA").map { |name| name.strip.downcase }
        end

        def views
          schema = @config[:schema]&.upcase
          sql = <<~SQL
            SELECT TABLE_NAME
            FROM QSYS2.SYSTABLES
            WHERE TABLE_SCHEMA = '#{schema}'
              AND TABLE_TYPE = 'V'
            ORDER BY TABLE_NAME
          SQL
          query_values(sql, "SCHEMA").map { |name| name.strip.downcase }
        end

        def table_exists?(table_name)
          schema = @config[:schema]&.upcase
          tbl = table_name.to_s.upcase
          sql = <<~SQL
            SELECT COUNT(*)
            FROM QSYS2.SYSTABLES
            WHERE TABLE_SCHEMA = '#{schema}'
              AND TABLE_NAME = '#{tbl}'
              AND TABLE_TYPE IN ('T', 'P')
          SQL
          query_value(sql, "SCHEMA").to_i > 0
        end

        def view_exists?(view_name)
          schema = @config[:schema]&.upcase
          vw = view_name.to_s.upcase
          sql = <<~SQL
            SELECT COUNT(*)
            FROM QSYS2.SYSTABLES
            WHERE TABLE_SCHEMA = '#{schema}'
              AND TABLE_NAME = '#{vw}'
              AND TABLE_TYPE = 'V'
          SQL
          query_value(sql, "SCHEMA").to_i > 0
        end

        def primary_keys(table_name)
          schema = @config[:schema]&.upcase
          tbl = table_name.to_s.upcase

          sql = <<~SQL
            SELECT KC.COLUMN_NAME
            FROM QSYS2.SYSKEYCST KC
            INNER JOIN QSYS2.SYSCST CST
              ON KC.CONSTRAINT_SCHEMA = CST.CONSTRAINT_SCHEMA
              AND KC.CONSTRAINT_NAME = CST.CONSTRAINT_NAME
            WHERE CST.TABLE_SCHEMA = '#{schema}'
              AND CST.TABLE_NAME = '#{tbl}'
              AND CST.CONSTRAINT_TYPE = 'PRIMARY KEY'
            ORDER BY KC.ORDINAL_POSITION
          SQL

          query_values(sql, "SCHEMA").map { |name| name.strip.downcase }
        end

        def indexes(table_name)
          schema = @config[:schema]&.upcase
          tbl = table_name.to_s.upcase

          sql = <<~SQL
            SELECT
              IX.INDEX_NAME,
              IX.IS_UNIQUE,
              KC.COLUMN_NAME,
              KC.ORDINAL_POSITION,
              KC.ORDERING
            FROM QSYS2.SYSINDEXES IX
            INNER JOIN QSYS2.SYSKEYS KC
              ON IX.INDEX_SCHEMA = KC.INDEX_SCHEMA
              AND IX.INDEX_NAME = KC.INDEX_NAME
            WHERE IX.TABLE_SCHEMA = '#{schema}'
              AND IX.TABLE_NAME = '#{tbl}'
              AND IX.INDEX_NAME NOT IN (
                SELECT CONSTRAINT_NAME FROM QSYS2.SYSCST
                WHERE TABLE_SCHEMA = '#{schema}'
                  AND TABLE_NAME = '#{tbl}'
                  AND CONSTRAINT_TYPE = 'PRIMARY KEY'
              )
            ORDER BY IX.INDEX_NAME, KC.ORDINAL_POSITION
          SQL

          result = internal_exec_query(sql, "SCHEMA")

          indexes_hash = {}
          result.each do |row|
            idx_name = row["index_name"].strip.downcase
            indexes_hash[idx_name] ||= {
              unique: row["is_unique"]&.strip == "U",
              columns: [],
              orders: {}
            }
            col = row["column_name"].strip.downcase
            indexes_hash[idx_name][:columns] << col
            if row["ordering"]&.strip == "D"
              indexes_hash[idx_name][:orders][col] = :desc
            end
          end

          indexes_hash.map do |name, data|
            IndexDefinition.new(
              table_name.to_s,
              name,
              data[:unique],
              data[:columns],
              orders: data[:orders].presence || {}
            )
          end
        end

        def foreign_keys(table_name)
          schema = @config[:schema]&.upcase
          tbl = table_name.to_s.upcase

          sql = <<~SQL
            SELECT
              RC.CONSTRAINT_NAME AS FK_NAME,
              KC.COLUMN_NAME,
              RC.UNIQUE_CONSTRAINT_SCHEMA AS REF_SCHEMA,
              UC.TABLE_NAME AS REFERENCED_TABLE_NAME,
              RKC.COLUMN_NAME AS REFERENCED_COLUMN_NAME,
              CST.DELETE_RULE,
              CST.UPDATE_RULE
            FROM QSYS2.SYSREFCST RC
            INNER JOIN QSYS2.SYSCST CST
              ON RC.CONSTRAINT_SCHEMA = CST.CONSTRAINT_SCHEMA
              AND RC.CONSTRAINT_NAME = CST.CONSTRAINT_NAME
            INNER JOIN QSYS2.SYSKEYCST KC
              ON RC.CONSTRAINT_SCHEMA = KC.CONSTRAINT_SCHEMA
              AND RC.CONSTRAINT_NAME = KC.CONSTRAINT_NAME
            INNER JOIN QSYS2.SYSCST UC
              ON RC.UNIQUE_CONSTRAINT_SCHEMA = UC.CONSTRAINT_SCHEMA
              AND RC.UNIQUE_CONSTRAINT_NAME = UC.CONSTRAINT_NAME
            INNER JOIN QSYS2.SYSKEYCST RKC
              ON RC.UNIQUE_CONSTRAINT_SCHEMA = RKC.CONSTRAINT_SCHEMA
              AND RC.UNIQUE_CONSTRAINT_NAME = RKC.CONSTRAINT_NAME
              AND KC.ORDINAL_POSITION = RKC.ORDINAL_POSITION
            WHERE CST.TABLE_SCHEMA = '#{schema}'
              AND CST.TABLE_NAME = '#{tbl}'
            ORDER BY RC.CONSTRAINT_NAME, KC.ORDINAL_POSITION
          SQL

          result = internal_exec_query(sql, "SCHEMA")

          fk_hash = {}
          result.each do |row|
            fk_name = row["fk_name"]&.strip
            fk_hash[fk_name] ||= {
              from_columns: [],
              to_table: row["referenced_table_name"]&.strip&.downcase,
              to_columns: [],
              on_delete: extract_fk_action(row["delete_rule"]),
              on_update: extract_fk_action(row["update_rule"]),
            }
            fk_hash[fk_name][:from_columns] << row["column_name"]&.strip&.downcase
            fk_hash[fk_name][:to_columns] << row["referenced_column_name"]&.strip&.downcase
          end

          fk_hash.map do |name, data|
            options = {
              name: name,
              column: data[:from_columns].size == 1 ? data[:from_columns].first : data[:from_columns],
              primary_key: data[:to_columns].size == 1 ? data[:to_columns].first : data[:to_columns],
              on_delete: data[:on_delete],
              on_update: data[:on_update],
            }
            ForeignKeyDefinition.new(table_name.to_s, data[:to_table], options)
          end
        end

        # -- DDL Methods --

        def rename_table(table_name, new_name, **)
          execute("RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}")
        end

        def drop_table(table_name, **options)
          execute("DROP TABLE #{quote_table_name(table_name)}")
        end

        def change_column(table_name, column_name, type, **options)
          sql_type = type_to_sql(type, **options.slice(:limit, :precision, :scale))
          execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DATA TYPE #{sql_type}")

          if options.key?(:null)
            change_column_null(table_name, column_name, options[:null])
          end

          if options.key?(:default)
            change_column_default(table_name, column_name, options[:default])
          end
        end

        def change_column_default(table_name, column_name, default_or_changes)
          default = extract_new_default_value(default_or_changes)
          if default.nil?
            execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} DROP DEFAULT")
          else
            execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}")
          end
        end

        def change_column_null(table_name, column_name, null, default = nil)
          unless null || default.nil?
            execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)} = #{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
          end

          if null
            execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} DROP NOT NULL")
          else
            execute("ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET NOT NULL")
          end
        end

        def rename_column(table_name, column_name, new_column_name)
          execute("ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}")
        end

        def add_index(table_name, column_name, **options)
          index_name = options[:name] || index_name(table_name, column_name)
          unique = options[:unique] ? "UNIQUE " : ""

          columns = Array(column_name).map do |col|
            order = options[:order].is_a?(Hash) ? options[:order][col] : nil
            "#{quote_column_name(col)}#{" DESC" if order.to_s == "desc"}"
          end.join(", ")

          execute("CREATE #{unique}INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{columns})")
        end

        def remove_index(table_name, column_name = nil, **options)
          index_name = options[:name] || index_name(table_name, column_name)
          execute("DROP INDEX #{quote_column_name(index_name)}")
        end

        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **)
          native = native_database_types[type.to_sym]
          return type.to_s unless native

          sql_type = native.is_a?(Hash) ? native[:name] : native

          case type.to_sym
          when :string, :char
            limit ||= native[:limit] if native.is_a?(Hash)
            limit ? "#{sql_type}(#{limit})" : sql_type
          when :decimal
            if precision
              scale ? "#{sql_type}(#{precision},#{scale})" : "#{sql_type}(#{precision})"
            else
              sql_type
            end
          when :integer
            if limit
              case limit
              when 1, 2 then "SMALLINT"
              when 3, 4 then "INTEGER"
              when 5..8 then "BIGINT"
              else sql_type
              end
            else
              sql_type
            end
          when :text, :binary, :float, :date, :time, :datetime, :timestamp, :boolean, :bigint
            sql_type
          else
            sql_type
          end
        end

        def schema_creation
          Peasys::SchemaCreation.new(self)
        end

        def create_table_definition(name, **options)
          Peasys::TableDefinition.new(self, name, **options)
        end

        # Tells Rails to use our custom SchemaDumper
        def schema_dumper_class
          Peasys::SchemaDumper
        end

        # -- Rails internal tables --

        # Ensures the schema_migrations table exists with DB2-compatible types.
        def create_schema_migrations_table
          unless table_exists?("schema_migrations")
            execute(<<~SQL)
              CREATE TABLE #{quote_table_name("schema_migrations")} (
                "VERSION" VARCHAR(255) NOT NULL PRIMARY KEY
              )
            SQL
          end
        end

        # Ensures the ar_internal_metadata table exists with DB2-compatible types.
        def create_internal_metadata_table
          unless table_exists?("ar_internal_metadata")
            execute(<<~SQL)
              CREATE TABLE #{quote_table_name("ar_internal_metadata")} (
                "KEY" VARCHAR(255) NOT NULL PRIMARY KEY,
                "VALUE" VARCHAR(255),
                "CREATED_AT" TIMESTAMP NOT NULL,
                "UPDATED_AT" TIMESTAMP NOT NULL
              )
            SQL
          end
        end

        private

          def column_definitions(table_name)
            schema = @config[:schema]&.upcase
            tbl = table_name.to_s.upcase

            sql = <<~SQL
              SELECT
                COLUMN_NAME,
                DATA_TYPE,
                LENGTH AS COLUMN_SIZE,
                NUMERIC_SCALE,
                NUMERIC_PRECISION,
                IS_NULLABLE,
                COLUMN_DEFAULT,
                HAS_DEFAULT,
                IS_IDENTITY,
                ORDINAL_POSITION,
                COLUMN_TEXT AS COLUMN_COMMENT,
                CCSID
              FROM QSYS2.SYSCOLUMNS
              WHERE TABLE_SCHEMA = '#{schema}'
                AND TABLE_NAME = '#{tbl}'
              ORDER BY ORDINAL_POSITION
            SQL

            internal_exec_query(sql, "SCHEMA").to_a
          end

          def new_column_from_field(table_name, field, _definitions)
            name       = field["column_name"]&.strip&.downcase
            sql_type   = field["data_type"]&.strip
            default    = field["column_default"]&.strip
            null       = field["is_nullable"]&.strip == "Y"
            is_identity = field["is_identity"]&.strip == "YES"
            precision  = field["numeric_precision"]
            scale      = field["numeric_scale"]
            limit      = field["column_size"]
            comment    = field["column_comment"]&.strip

            full_sql_type = build_full_sql_type(sql_type, limit, precision, scale)
            type_metadata = fetch_type_metadata(full_sql_type)

            default_value = extract_value_from_default(default)
            default_function = extract_default_function(default, default_value)

            ActiveRecord::ConnectionAdapters::Column.new(
              name,
              default_value,
              type_metadata,
              null,
              default_function,
              comment: comment.presence
            )
          end

          def build_full_sql_type(sql_type, limit, precision, scale)
            case sql_type&.upcase
            when "VARCHAR", "CHAR", "CHARACTER", "CHARACTER VARYING", "VARGRAPHIC", "GRAPHIC"
              "#{sql_type}(#{limit})"
            when "DECIMAL", "NUMERIC"
              "#{sql_type}(#{precision},#{scale})"
            else
              sql_type.to_s
            end
          end

          def extract_value_from_default(default)
            return nil if default.nil? || default.empty?

            case default
            when /\ANULL\z/i                    then nil
            when /\A'(.*)'\z/m                  then $1.gsub("''", "'")
            when /\A(-?\d+(\.\d*)?)\z/          then $1
            when /\ACURRENT_TIMESTAMP\z/i,
                 /\ACURRENT_DATE\z/i,
                 /\ACURRENT_TIME\z/i            then nil
            else default
            end
          end

          def extract_default_function(default, default_value)
            return nil if default.nil? || default.empty?

            if default_value.nil? && default =~ /\A(CURRENT_TIMESTAMP|CURRENT_DATE|CURRENT_TIME)\z/i
              default
            end
          end

          def extract_fk_action(rule)
            case rule&.strip
            when "CASCADE"     then :cascade
            when "SET NULL"    then :nullify
            when "SET DEFAULT" then :default
            when "RESTRICT"    then :restrict
            when "NO ACTION"   then nil
            else nil
            end
          end
      end
    end
  end
end
