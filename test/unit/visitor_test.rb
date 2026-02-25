# frozen_string_literal: true

require_relative "../test_helper"

class VisitorTest < Minitest::Test
  def setup
    @visitor = Arel::Visitors::Peasys.new(nil)
    @table = Arel::Table.new(:users)
    @collector = Arel::Collectors::SQLString.new
  end

  def test_visitor_exists
    assert_kind_of Arel::Visitors::ToSql, @visitor
  end

  def test_limit_generates_fetch_first
    # Use SqlLiteral to avoid needing a connection for quoting
    limit_node = Arel::Nodes::Limit.new(Arel::Nodes::SqlLiteral.new("10"))
    result = @visitor.accept(limit_node, @collector)
    assert_match(/FETCH FIRST/, result.value)
    assert_match(/10/, result.value)
    assert_match(/ROWS ONLY/, result.value)
  end

  def test_offset_generates_offset_rows
    offset_node = Arel::Nodes::Offset.new(Arel::Nodes::SqlLiteral.new("5"))
    result = @visitor.accept(offset_node, @collector)
    assert_match(/OFFSET/, result.value)
    assert_match(/5/, result.value)
    assert_match(/ROWS/, result.value)
  end

  def test_true_generates_1
    true_node = Arel::Nodes::True.new
    result = @visitor.accept(true_node, @collector)
    assert_equal "1", result.value
  end

  def test_false_generates_0
    false_node = Arel::Nodes::False.new
    result = @visitor.accept(false_node, @collector)
    assert_equal "0", result.value
  end

  def test_lock_generates_for_update
    lock_node = Arel::Nodes::Lock.new(true)
    result = @visitor.accept(lock_node, @collector)
    assert_match(/FOR UPDATE WITH RS/, result.value)
  end

  def test_lock_with_custom_string
    lock_node = Arel::Nodes::Lock.new("FOR READ ONLY")
    result = @visitor.accept(lock_node, @collector)
    assert_match(/FOR READ ONLY/, result.value)
  end
end
