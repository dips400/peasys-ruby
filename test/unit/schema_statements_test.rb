# frozen_string_literal: true

require_relative "../test_helper"

class SchemaStatementsTest < Minitest::Test
  include PeasysTestHelper

  def test_type_to_sql_string
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "VARCHAR(255)", adapter.type_to_sql(:string)
      assert_equal "VARCHAR(100)", adapter.type_to_sql(:string, limit: 100)
    end
  end

  def test_type_to_sql_text
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "CLOB", adapter.type_to_sql(:text)
    end
  end

  def test_type_to_sql_integer
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "INTEGER", adapter.type_to_sql(:integer)
    end
  end

  def test_type_to_sql_integer_with_limits
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "SMALLINT", adapter.type_to_sql(:integer, limit: 1)
      assert_equal "SMALLINT", adapter.type_to_sql(:integer, limit: 2)
      assert_equal "INTEGER", adapter.type_to_sql(:integer, limit: 3)
      assert_equal "INTEGER", adapter.type_to_sql(:integer, limit: 4)
      assert_equal "BIGINT", adapter.type_to_sql(:integer, limit: 5)
      assert_equal "BIGINT", adapter.type_to_sql(:integer, limit: 8)
    end
  end

  def test_type_to_sql_decimal
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "DECIMAL", adapter.type_to_sql(:decimal)
      assert_equal "DECIMAL(10)", adapter.type_to_sql(:decimal, precision: 10)
      assert_equal "DECIMAL(10,2)", adapter.type_to_sql(:decimal, precision: 10, scale: 2)
    end
  end

  def test_type_to_sql_float
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "DOUBLE", adapter.type_to_sql(:float)
    end
  end

  def test_type_to_sql_datetime
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "TIMESTAMP", adapter.type_to_sql(:datetime)
    end
  end

  def test_type_to_sql_binary
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "BLOB", adapter.type_to_sql(:binary)
    end
  end

  def test_type_to_sql_boolean
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "SMALLINT", adapter.type_to_sql(:boolean)
    end
  end

  def test_type_to_sql_bigint
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "BIGINT", adapter.type_to_sql(:bigint)
    end
  end

  def test_tables_queries_qsys2
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/QSYS2\.SYSTABLES/m, {
        "TABLE_NAME" => ["USERS    ", "ORDERS   "]
      }, ["TABLE_NAME"])

      tables = adapter.tables

      assert_equal ["users", "orders"], tables
      query_sql = mock.queries.last.last
      assert_match(/QSYS2\.SYSTABLES/, query_sql)
      assert_match(/TABLE_SCHEMA = 'TESTLIB'/, query_sql)
      assert_match(/TABLE_TYPE = 'T'/, query_sql)
    end
  end

  def test_views_queries_qsys2
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/QSYS2\.SYSTABLES/m, {
        "TABLE_NAME" => ["ACTIVE_USERS"]
      }, ["TABLE_NAME"])

      views = adapter.views

      assert_equal ["active_users"], views
    end
  end

  def test_primary_keys_queries_qsys2
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/QSYS2\.SYSKEYCST/m, {
        "COLUMN_NAME" => ["ID  "]
      }, ["COLUMN_NAME"])

      keys = adapter.primary_keys("users")

      assert_equal ["id"], keys
    end
  end

  def test_drop_table_generates_correct_sql
    create_adapter_with_mock do |adapter, mock|
      adapter.drop_table("users")

      sql = mock.queries.last.last
      assert_match(/DROP TABLE "USERS"/, sql)
    end
  end

  def test_rename_table_generates_correct_sql
    create_adapter_with_mock do |adapter, mock|
      adapter.rename_table("users", "people")

      sql = mock.queries.last.last
      assert_match(/RENAME TABLE "USERS" TO "PEOPLE"/, sql)
    end
  end

  def test_rename_column_generates_correct_sql
    create_adapter_with_mock do |adapter, mock|
      adapter.rename_column("users", "name", "full_name")

      sql = mock.queries.last.last
      assert_match(/ALTER TABLE "USERS" RENAME COLUMN "NAME" TO "FULL_NAME"/, sql)
    end
  end

  def test_change_column_null_set_not_null
    create_adapter_with_mock do |adapter, mock|
      adapter.change_column_null("users", "name", false)

      sql = mock.queries.last.last
      assert_match(/ALTER TABLE "USERS" ALTER COLUMN "NAME" SET NOT NULL/, sql)
    end
  end

  def test_change_column_null_drop_not_null
    create_adapter_with_mock do |adapter, mock|
      adapter.change_column_null("users", "name", true)

      sql = mock.queries.last.last
      assert_match(/ALTER TABLE "USERS" ALTER COLUMN "NAME" DROP NOT NULL/, sql)
    end
  end

  def test_add_index_simple
    create_adapter_with_mock do |adapter, mock|
      adapter.add_index("users", "email")

      sql = mock.queries.last.last
      assert_match(/CREATE\s+INDEX/, sql)
      assert_match(/"EMAIL"/, sql)
      assert_match(/ON "USERS"/, sql)
    end
  end

  def test_add_index_unique
    create_adapter_with_mock do |adapter, mock|
      adapter.add_index("users", "email", unique: true)

      sql = mock.queries.last.last
      assert_match(/CREATE UNIQUE INDEX/, sql)
    end
  end

  def test_remove_index
    create_adapter_with_mock do |adapter, mock|
      adapter.remove_index("users", name: "idx_users_email")

      sql = mock.queries.last.last
      assert_match(/DROP INDEX "IDX_USERS_EMAIL"/, sql)
    end
  end
end
