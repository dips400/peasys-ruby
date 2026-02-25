# frozen_string_literal: true

module Arel
  module Visitors
    class Peasys < Arel::Visitors::ToSql
      private

        # DB2 uses FETCH FIRST n ROWS ONLY instead of LIMIT
        def visit_Arel_Nodes_Limit(o, collector)
          collector << " FETCH FIRST "
          visit o.expr, collector
          collector << " ROWS ONLY"
        end

        # DB2 uses OFFSET n ROWS
        def visit_Arel_Nodes_Offset(o, collector)
          collector << " OFFSET "
          visit o.expr, collector
          collector << " ROWS"
        end

        # DB2 boolean literals: 1/0 instead of TRUE/FALSE
        def visit_Arel_Nodes_True(o, collector)
          collector << "1"
        end

        def visit_Arel_Nodes_False(o, collector)
          collector << "0"
        end

        # DB2 FOR UPDATE syntax
        def visit_Arel_Nodes_Lock(o, collector)
          case o.expr
          when true
            collector << " FOR UPDATE WITH RS"
          when String
            collector << " " << o.expr
          else
            collector
          end
        end

        # DB2 string concatenation uses ||
        def visit_Arel_Nodes_Concat(o, collector)
          collector << "("
          visit o.left, collector
          collector << " || "
          visit o.right, collector
          collector << ")"
        end
    end
  end
end
