# frozen_string_literal: true

require_relative "../test_helper"

class DatabaseStatementsTest < Minitest::Test
  include PeasysTestHelper

  def test_select_query_routes_to_execute_select
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/SELECT/, { "ID" => ["1", "2"], "NAME" => ["Alice", "Bob"] })

      result = adapter.internal_exec_query("SELECT ID, NAME FROM USERS")

      assert_equal 2, result.length
      assert_equal ["id", "name"], result.columns
      assert_equal [["1", "Alice"], ["2", "Bob"]], result.rows
      assert_equal :select, mock.queries.last.first
    end
  end

  def test_select_with_empty_result
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/SELECT/, {})

      result = adapter.internal_exec_query("SELECT * FROM EMPTY_TABLE")

      assert_equal 0, result.length
    end
  end

  def test_with_cte_routes_to_execute_select
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/WITH|SELECT/, { "TOTAL" => ["42"] })

      result = adapter.internal_exec_query("WITH cte AS (SELECT 1) SELECT * FROM cte")

      assert_equal :select, mock.queries.last.first
    end
  end

  def test_insert_query_routes_to_execute_insert
    create_adapter_with_mock do |adapter, mock|
      adapter.internal_exec_query("INSERT INTO USERS (NAME) VALUES ('Alice')")

      assert_equal :insert, mock.queries.last.first
    end
  end

  def test_update_query_routes_to_execute_update
    create_adapter_with_mock do |adapter, mock|
      adapter.internal_exec_query("UPDATE USERS SET NAME = 'Bob' WHERE ID = 1")

      assert_equal :update, mock.queries.last.first
    end
  end

  def test_delete_query_routes_to_execute_delete
    create_adapter_with_mock do |adapter, mock|
      adapter.internal_exec_query("DELETE FROM USERS WHERE ID = 1")

      assert_equal :delete, mock.queries.last.first
    end
  end

  def test_create_query_routes_to_execute_create
    create_adapter_with_mock do |adapter, mock|
      adapter.execute("CREATE TABLE TEST (ID INTEGER)")

      assert_equal :create, mock.queries.last.first
    end
  end

  def test_alter_query_routes_to_execute_alter
    create_adapter_with_mock do |adapter, mock|
      adapter.execute("ALTER TABLE TEST ADD COLUMN NAME VARCHAR(255)")

      assert_equal :alter, mock.queries.last.first
    end
  end

  def test_drop_query_routes_to_execute_drop
    create_adapter_with_mock do |adapter, mock|
      adapter.execute("DROP TABLE TEST")

      assert_equal :drop, mock.queries.last.first
    end
  end

  def test_set_query_routes_to_execute_sql
    create_adapter_with_mock do |adapter, mock|
      adapter.execute("SET SCHEMA MYLIB")

      assert_equal :sql, mock.queries.last.first
    end
  end

  def test_commit_sends_commit
    create_adapter_with_mock do |adapter, mock|
      adapter.commit_db_transaction

      assert_equal :sql, mock.queries.last.first
      assert_match(/COMMIT/, mock.queries.last.last)
    end
  end

  def test_rollback_sends_rollback
    create_adapter_with_mock do |adapter, mock|
      adapter.exec_rollback_db_transaction

      assert_equal :sql, mock.queries.last.first
      assert_match(/ROLLBACK/, mock.queries.last.last)
    end
  end

  def test_exec_delete_returns_row_count
    create_adapter_with_mock do |adapter, mock|
      count = adapter.exec_delete("DELETE FROM USERS WHERE ID = 1")

      assert_equal 1, count
    end
  end

  def test_exec_update_returns_row_count
    create_adapter_with_mock do |adapter, mock|
      count = adapter.exec_update("UPDATE USERS SET NAME = 'Bob' WHERE ID = 1")

      assert_equal 1, count
    end
  end

  def test_columnar_to_row_transposition
    create_adapter_with_mock do |adapter, mock|
      # Simulate a 3-row, 2-column result
      mock.mock_select(/SELECT/, {
        "COL_A" => ["x", "y", "z"],
        "COL_B" => ["1", "2", "3"]
      }, ["COL_A", "COL_B"])

      result = adapter.internal_exec_query("SELECT COL_A, COL_B FROM T")

      assert_equal ["col_a", "col_b"], result.columns
      assert_equal [["x", "1"], ["y", "2"], ["z", "3"]], result.rows
    end
  end

  def test_single_column_result
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/SELECT/, { "COUNT" => ["42"] }, ["COUNT"])

      result = adapter.internal_exec_query("SELECT COUNT(*) AS COUNT FROM USERS")

      assert_equal ["count"], result.columns
      assert_equal [["42"]], result.rows
    end
  end
end
