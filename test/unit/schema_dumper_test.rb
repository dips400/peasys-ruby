# frozen_string_literal: true

require_relative "../test_helper"

class SchemaDumperTest < Minitest::Test
  def test_schema_dumper_class_exists
    assert_kind_of Class, ActiveRecord::ConnectionAdapters::Peasys::SchemaDumper
  end

  def test_schema_dumper_inherits_from_connection_adapters
    assert ActiveRecord::ConnectionAdapters::Peasys::SchemaDumper < ActiveRecord::ConnectionAdapters::SchemaDumper
  end

  include PeasysTestHelper

  def test_schema_dumper_class_returned_by_adapter
    create_adapter_with_mock do |adapter, _mock|
      assert_equal ActiveRecord::ConnectionAdapters::Peasys::SchemaDumper,
                   adapter.schema_dumper_class
    end
  end

  def test_create_schema_migrations_table
    create_adapter_with_mock do |adapter, mock|
      # Table does not exist yet (mock returns 0 count)
      mock.mock_select(/QSYS2\.SYSTABLES/, { "COUNT" => ["0"] }, ["COUNT"])

      adapter.create_schema_migrations_table

      # Should have issued a CREATE TABLE
      create_queries = mock.queries.select { |type, _| type == :create }
      refute_empty create_queries, "Expected a CREATE TABLE query"

      sql = create_queries.last.last
      assert_match(/SCHEMA_MIGRATIONS/i, sql)
      assert_match(/VERSION/i, sql)
      assert_match(/VARCHAR/, sql)
      assert_match(/PRIMARY KEY/, sql)
    end
  end

  def test_create_schema_migrations_table_skips_if_exists
    create_adapter_with_mock do |adapter, mock|
      # Table already exists (mock returns 1 count)
      mock.mock_select(/QSYS2\.SYSTABLES/, { "COUNT" => ["1"] }, ["COUNT"])

      adapter.create_schema_migrations_table

      # Should NOT have issued a CREATE TABLE
      create_queries = mock.queries.select { |type, _| type == :create }
      assert_empty create_queries, "Should not create table when it already exists"
    end
  end

  def test_create_internal_metadata_table
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/QSYS2\.SYSTABLES/, { "COUNT" => ["0"] }, ["COUNT"])

      adapter.create_internal_metadata_table

      create_queries = mock.queries.select { |type, _| type == :create }
      refute_empty create_queries, "Expected a CREATE TABLE query"

      sql = create_queries.last.last
      assert_match(/AR_INTERNAL_METADATA/i, sql)
      assert_match(/KEY/i, sql)
      assert_match(/VALUE/i, sql)
      assert_match(/CREATED_AT/i, sql)
      assert_match(/UPDATED_AT/i, sql)
      assert_match(/TIMESTAMP/, sql)
    end
  end

  def test_create_internal_metadata_table_skips_if_exists
    create_adapter_with_mock do |adapter, mock|
      mock.mock_select(/QSYS2\.SYSTABLES/, { "COUNT" => ["1"] }, ["COUNT"])

      adapter.create_internal_metadata_table

      create_queries = mock.queries.select { |type, _| type == :create }
      assert_empty create_queries, "Should not create table when it already exists"
    end
  end
end
