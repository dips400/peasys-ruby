# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Peasys
      module DatabaseStatements
        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :begin, :commit, :rollback, :savepoint, :release, :set
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql)
          !READ_QUERY.match?(sql)
        rescue ArgumentError
          !READ_QUERY.match?(sql.b)
        end

        def internal_exec_query(sql, name = nil, binds = [], prepare: false, async: false, allow_retry: false)
          sql = transform_query(sql)
          check_if_write_query(sql)
          mark_transaction_written_if_write(sql)

          type_casted_binds = type_casted_binds(binds)
          bound_sql = bind_params_to_sql(sql, type_casted_binds)

          log(bound_sql, name, binds, type_casted_binds, async: async) do |notification_payload|
            with_raw_connection do |conn|
              columns, rows = execute_and_extract(conn, bound_sql)
              verified!
              result = build_result(columns: columns, rows: rows)
              notification_payload[:row_count] = result.length if notification_payload
              result
            end
          end
        end

        def execute(sql, name = nil, allow_retry: false)
          sql = transform_query(sql)
          check_if_write_query(sql)
          mark_transaction_written_if_write(sql)

          log(sql, name) do
            with_raw_connection do |conn|
              execute_and_extract(conn, sql)
              verified!
            end
          end
        end

        def exec_delete(sql, name = nil, binds = [])
          sql = transform_query(sql)
          type_casted_binds = type_casted_binds(binds)
          bound_sql = bind_params_to_sql(sql, type_casted_binds)

          log(bound_sql, name, binds, type_casted_binds) do
            with_raw_connection do |conn|
              keyword = bound_sql.strip.split(/\s+/, 2).first.upcase
              case keyword
              when "DELETE"
                response = conn.execute_delete(bound_sql)
                raise_if_failed(response, bound_sql)
                verified!
                response.row_count
              when "UPDATE"
                response = conn.execute_update(bound_sql)
                raise_if_failed(response, bound_sql)
                verified!
                response.row_count
              else
                execute_and_extract(conn, bound_sql)
                verified!
                0
              end
            end
          end
        end
        alias exec_update exec_delete

        def begin_db_transaction
          # DB2 on IBM i uses implicit transactions.
          # We send a SET TRANSACTION ISOLATION LEVEL to mark the start.
          # Alternatively, we just track state -- COMMIT/ROLLBACK are explicit.
        end

        def commit_db_transaction
          with_raw_connection do |conn|
            conn.execute_sql("COMMIT")
          end
        end

        def exec_rollback_db_transaction
          with_raw_connection do |conn|
            conn.execute_sql("ROLLBACK")
          end
        end

        def default_sequence_name(table_name, _column = nil)
          nil
        end

        private

          # Transposes PeaSelectResponse columnar format to row-based format.
          #
          # PeaClient returns: { "COL1" => ["a","b"], "COL2" => [1, 2] }
          # AR expects: columns=["col1","col2"], rows=[["a",1],["b",2]]
          def transpose_columnar_result(response)
            columns = response.columns_name.map { |c| c.to_s.downcase }
            row_count = response.row_count.to_i
            return [columns, []] if row_count == 0

            rows = Array.new(row_count) { Array.new(columns.size) }

            response.columns_name.each_with_index do |original_name, col_idx|
              values = response.result[original_name] || []
              values.each_with_index do |val, row_idx|
                rows[row_idx][col_idx] = val
              end
            end

            [columns, rows]
          end

          # Routes SQL to the appropriate PeaClient method based on the statement keyword.
          def execute_and_extract(conn, sql)
            keyword = sql.strip.split(/\s+/, 2).first.upcase

            case keyword
            when "SELECT", "WITH"
              response = conn.execute_select(sql)
              raise_if_failed(response, sql)
              transpose_columnar_result(response)
            when "INSERT"
              response = conn.execute_insert(sql)
              raise_if_failed(response, sql)
              [[], []]
            when "UPDATE"
              response = conn.execute_update(sql)
              raise_if_failed(response, sql)
              [[], []]
            when "DELETE"
              response = conn.execute_delete(sql)
              raise_if_failed(response, sql)
              [[], []]
            when "CREATE"
              response = conn.execute_create(sql)
              raise_if_failed(response, sql)
              [[], []]
            when "ALTER"
              response = conn.execute_alter(sql, false)
              raise_if_failed(response, sql)
              [[], []]
            when "DROP"
              response = conn.execute_drop(sql)
              raise_if_failed(response, sql)
              [[], []]
            else
              # SET, COMMIT, ROLLBACK, GRANT, REVOKE, etc.
              response = conn.execute_sql(sql)
              raise_if_failed(response, sql)
              [[], []]
            end
          end

          def raise_if_failed(response, sql)
            return if response.has_succeeded

            raise ActiveRecord::StatementInvalid.new(
              "DB2 Error [#{response.sql_state}]: #{response.sql_message}",
              sql: sql,
              connection_pool: @pool
            )
          end

          # PeaClient has no prepared statement support.
          # Substitutes bind parameters (?) directly into SQL with proper quoting.
          def bind_params_to_sql(sql, type_casted_binds)
            return sql if type_casted_binds.empty?

            binds = type_casted_binds.dup
            sql.gsub("?") do
              val = binds.shift
              if val.nil?
                "NULL"
              else
                quote(val)
              end
            end
          end

          def last_inserted_id(result)
            with_raw_connection do |conn|
              response = conn.execute_select(
                "SELECT IDENTITY_VAL_LOCAL() AS LAST_ID FROM SYSIBM.SYSDUMMY1"
              )
              if response.has_succeeded && response.row_count.to_i > 0
                val = response.result["LAST_ID"]&.first
                val&.to_i
              end
            end
          end

          def build_truncate_statement(table_name)
            "DELETE FROM #{quote_table_name(table_name)}"
          end
      end
    end
  end
end
