module TableGo
  module Renderers
    module RendererBase
      extend ActiveSupport::Concern

      included do
        attr_accessor :table, :template
        delegate :content_tag, :concat, :to => :template
      end

      def render_template
        raise ArgumentError.new('implement #render_template in concrete renderer')
      end

      private

        def label_for_column(column)
          column.label || begin
            if column.method && 1==3# reflection = table.model_klass.reflections[column.name]
              reflection.klass.human_attribute_name(column.method).html_safe
            # if column.method && reflection = table.model_klass.reflections[column.name]
            #   reflection.klass.human_attribute_name(column.method).html_safe
            else
              column.human_attribute_name
            end
          end
        end

        def html_options_for_header(column)
          {}.tap do |h|
            (column.header_html || {}).each do |k, v|
              h[k] = v.is_a?(Proc) ? v.call(column) : v
            end
          end
        end

        def html_options_for_row(record)
          {}.tap do |h|
            (table.row_html || {}).each do |k, v|
              h[k] = v.is_a?(Proc) ? v.call(record) : v
            end
          end
        end

        def html_options_for_cell(record, column, value)
          {}.tap do |h|
            (column.column_html || {}).each do |k, v|
              h[k] = v.is_a?(Proc) ? v.call(record, column, value) : v
            end
          end
        end

        def value_from_record_by_column(record, column)
          if record.respond_to?(column.name)
            value = record.send(column.name)
            column.method ? value.send(column.method) : value
          else
            ''
          end
        end

        def apply_formatter(record, column, value)
          begin
            case
              when formatter = column.as
                Formatter.apply(formatter, record, column, value)
              when formatter = column.send
                Formatter.apply_send(formatter, record, column, value)
              when formatter = column.block
                apply_formatter_for_block(formatter, record, column, value)
              else
                value
            end
          end.to_s.html_safe
        end

        def apply_formatter_for_block(formatter, record, column, value)
          # template.capture { Formatter.apply(formatter, record, column, value )}
          # template.capture_haml { Formatter.apply(formatter, record, column, value )}
          # template.send(:capture_haml) { Formatter.apply(formatter, record, column, value )}
          string = nil
          capture_view do
            string = Formatter.apply(formatter, record, column, value )
          end.presence || string # for compatibility to legacy haml "- t.column :ident"
        end


        def capture_view
          template.is_haml? ? capture_haml { yield } : template.capture { yield }
        end

        # stripped down ripoff from Haml's capture_haml, needed for speed
        def capture_haml(*args, &block)
          position = template.send(:haml_buffer).buffer.length

          template.send(:haml_buffer).capture_position = position
          block.call(*args)

          template.send(:haml_buffer).buffer.slice!(position..-1)
        ensure
          template.send(:haml_buffer).capture_position = nil
        end

    end
  end
end