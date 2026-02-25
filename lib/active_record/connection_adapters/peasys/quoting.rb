# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Peasys
      module Quoting
        extend ActiveSupport::Concern

        QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
        QUOTED_TABLE_NAMES  = Concurrent::Map.new # :nodoc:

        module ClassMethods # :nodoc:
          def column_name_matcher
            /
              \A
              (
                (?:
                  # "TABLE"."COLUMN" | function(one or two args)
                  ((?:\w+\.|"\w+"\.)?(?:\w+|"\w+") | \w+\((?:|\g<2>)\))
                )
                (?:(?:\s+AS)?\s+(?:\w+|"\w+"))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def column_name_with_order_matcher
            /
              \A
              (
                (?:
                  ((?:\w+\.|"\w+"\.)?(?:\w+|"\w+") | \w+\((?:|\g<2>)\))
                )
                (?:\s+ASC|\s+DESC)?
                (?:\s+NULLS\s+(?:FIRST|LAST))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def quote_column_name(name)
            QUOTED_COLUMN_NAMES[name] ||= %("#{name.to_s.gsub('"', '""').upcase}").freeze
          end

          def quote_table_name(name)
            QUOTED_TABLE_NAMES[name] ||= begin
              parts = name.to_s.split(".")
              parts.map { |p| %("#{p.gsub('"', '""').upcase}") }.join(".").freeze
            end
          end
        end

        def quote_string(s)
          s.gsub("'", "''")
        end

        def quoted_true
          "1"
        end

        def unquoted_true
          1
        end

        def quoted_false
          "0"
        end

        def unquoted_false
          0
        end

        def quoted_date(value)
          if value.acts_like?(:time)
            value.strftime("%Y-%m-%d %H:%M:%S.%6N")
          else
            value.to_s
          end
        end

        def quote_table_name_for_assignment(_table, attr)
          quote_column_name(attr)
        end

        private

          def type_cast(value)
            case value
            when true  then 1
            when false then 0
            else super
            end
          end
      end
    end
  end
end
