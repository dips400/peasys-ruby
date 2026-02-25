# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Peasys
      class Column < ConnectionAdapters::Column
        attr_reader :auto_increment

        def initialize(name, default, sql_type_metadata = nil, null = true, default_function = nil, comment: nil, auto_increment: false, **)
          super(name, default, sql_type_metadata, null, default_function, comment: comment)
          @auto_increment = auto_increment
        end

        def auto_increment?
          @auto_increment
        end
      end
    end
  end
end
