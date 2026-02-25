# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "peasys-ruby"

# Mock PeaClient that records queries and returns configurable responses.
# Used for unit testing the adapter without a live IBM i connection.
class MockPeaClient
  attr_reader :queries, :connexion_status

  def initialize
    @connexion_status = 1
    @queries = []
    @select_results = {}
  end

  # Register a mock result for SELECT queries matching a pattern
  def mock_select(pattern, result_hash, columns_name = nil)
    columns_name ||= result_hash.keys
    row_count = result_hash.values.first&.size || 0
    @select_results[pattern] = PeaSelectResponse.new(
      true, "00000", "00000", result_hash, row_count, columns_name
    )
  end

  def execute_select(query)
    @queries << [:select, query]
    @select_results.each do |pattern, response|
      return response if query.match?(pattern)
    end
    # Default: empty result
    PeaSelectResponse.new(true, "00000", "00000", {}, 0, [])
  end

  def execute_insert(query)
    @queries << [:insert, query]
    PeaInsertResponse.new(true, "00000", "00000", 1)
  end

  def execute_update(query)
    @queries << [:update, query]
    PeaUpdateResponse.new(true, "00000", "00000", 1)
  end

  def execute_delete(query)
    @queries << [:delete, query]
    PeaDeleteResponse.new(true, "00000", "00000", 1)
  end

  def execute_create(query)
    @queries << [:create, query]
    PeaCreateResponse.new(true, "00000", "00000", "", "", {})
  end

  def execute_alter(query, _retrieve_schema = false)
    @queries << [:alter, query]
    PeaAlterResponse.new(true, "00000", "00000", {})
  end

  def execute_drop(query)
    @queries << [:drop, query]
    PeaDropResponse.new(true, "00000", "00000")
  end

  def execute_sql(query)
    @queries << [:sql, query]
    PeaResponse.new(true, "00000", "00000")
  end

  def disconnect
    @connexion_status = 0
  end
end

# Helper to create a PeasysAdapter with a MockPeaClient without real connection
module PeasysTestHelper
  def create_adapter_with_mock
    config = {
      adapter: "peasys",
      ip_address: "127.0.0.1",
      partition_name: "TEST",
      port: 3000,
      username: "TESTUSER",
      password: "TESTPASS",
      id_client: "TEST",
      online_version: false,
      retrieve_statistics: false,
      schema: "TESTLIB"
    }

    mock = MockPeaClient.new

    # Stub new_client to return our mock
    ActiveRecord::ConnectionAdapters::PeasysAdapter.stub(:new_client, mock) do
      adapter = ActiveRecord::ConnectionAdapters::PeasysAdapter.new(config)
      # Force the raw_connection to be our mock
      adapter.instance_variable_set(:@raw_connection, mock)
      adapter.instance_variable_set(:@verified, true)
      yield adapter, mock
    end
  end
end
