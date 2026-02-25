# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Peasys
      class SchemaDumper < ConnectionAdapters::SchemaDumper
        private

          def header(stream)
            stream.puts <<~HEADER
              # This file is auto-generated from the current state of the database. Instead
              # of editing this file, please use the migrations feature of Active Record to
              # incrementally modify your database, and then regenerate this schema definition.
              #
              # This file is the source Rails uses to define your schema when running `bin/rails
              # db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
              # be faster and is potentially less error prone than running all of your
              # migrations from scratch. Old migrations may fail to apply correctly if those
              # migrations use external dependencies or application code.
              #
              # It's strongly recommended that you check this file into your version control system.

              ActiveRecord::Schema[#{ActiveRecord::Migration.current_version}].define(version: #{define_params}) do
            HEADER
          end

          # DB2 identity columns should be dumped as `bigint` or `integer` primary keys
          # with no explicit default (Rails infers the auto-increment behavior).
          def column_spec(column)
            spec = super
            spec[:auto_increment] = "true" if column.respond_to?(:auto_increment?) && column.auto_increment?
            spec
          end

          # Override to use DB2-specific type names in the dump
          def schema_type(column)
            case column.sql_type
            when /\ACLOB\z/i
              :text
            when /\ABLOB\z/i
              :binary
            when /\ASMALLINT\z/i
              :boolean
            when /\ATIMESTAMP\z/i
              :datetime
            when /\ADOUBLE\z/i
              :float
            when /\ABIGINT\z/i
              :bigint
            else
              super
            end
          end

          # Override to handle DB2's specific schema limit/precision/scale
          def schema_limit(column)
            case column.sql_type
            when /\ASMALLINT\z/i, /\AINTEGER\z/i, /\ABIGINT\z/i,
                 /\ACLOB\z/i, /\ABLOB\z/i, /\ADOUBLE\z/i, /\ATIMESTAMP\z/i
              nil
            else
              super
            end
          end

          def schema_precision(column)
            case column.sql_type
            when /\ATIMESTAMP\z/i
              nil
            else
              super
            end
          end

          # DB2 defaults that should not be dumped
          def schema_default(column)
            return nil if column.respond_to?(:auto_increment?) && column.auto_increment?

            super
          end

          def explicit_primary_key_default?(column)
            column.respond_to?(:auto_increment?) && column.auto_increment?
          end
      end
    end
  end
end
