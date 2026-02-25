# frozen_string_literal: true

require_relative "../test_helper"

class QuotingTest < Minitest::Test
  def test_quote_column_name_upcases
    result = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_column_name("name")
    assert_equal '"NAME"', result
  end

  def test_quote_column_name_with_underscore
    result = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_column_name("user_id")
    assert_equal '"USER_ID"', result
  end

  def test_quote_column_name_escapes_double_quotes
    result = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_column_name('col"name')
    assert_equal '"COL""NAME"', result
  end

  def test_quote_table_name_simple
    result = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_table_name("users")
    assert_equal '"USERS"', result
  end

  def test_quote_table_name_with_schema
    result = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_table_name("mylib.users")
    assert_equal '"MYLIB"."USERS"', result
  end

  def test_quote_table_name_caches
    result1 = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_table_name("orders")
    result2 = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_table_name("orders")
    assert_same result1, result2
  end

  def test_quote_column_name_caches
    result1 = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_column_name("email")
    result2 = ActiveRecord::ConnectionAdapters::PeasysAdapter.quote_column_name("email")
    assert_same result1, result2
  end

  include PeasysTestHelper

  def test_quote_string
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "it''s", adapter.quote_string("it's")
      assert_equal "hello", adapter.quote_string("hello")
      assert_equal "a''b''c", adapter.quote_string("a'b'c")
    end
  end

  def test_quoted_true
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "1", adapter.quoted_true
    end
  end

  def test_quoted_false
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "0", adapter.quoted_false
    end
  end

  def test_unquoted_true
    create_adapter_with_mock do |adapter, _mock|
      assert_equal 1, adapter.unquoted_true
    end
  end

  def test_unquoted_false
    create_adapter_with_mock do |adapter, _mock|
      assert_equal 0, adapter.unquoted_false
    end
  end

  def test_quoted_date_with_time
    create_adapter_with_mock do |adapter, _mock|
      time = Time.new(2024, 3, 15, 10, 30, 45)
      result = adapter.quoted_date(time)
      assert_match(/2024-03-15 10:30:45/, result)
    end
  end

  def test_quote_integer
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "42", adapter.quote(42)
    end
  end

  def test_quote_string_value
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "'hello'", adapter.quote("hello")
    end
  end

  def test_quote_string_with_single_quote
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "'it''s'", adapter.quote("it's")
    end
  end

  def test_quote_nil
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "NULL", adapter.quote(nil)
    end
  end

  def test_quote_true_becomes_1
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "1", adapter.quote(true)
    end
  end

  def test_quote_false_becomes_0
    create_adapter_with_mock do |adapter, _mock|
      assert_equal "0", adapter.quote(false)
    end
  end
end
