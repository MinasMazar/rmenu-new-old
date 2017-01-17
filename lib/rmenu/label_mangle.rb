
module RMenu
  module LabelMangle

    def item_mangle
      @item_mangle ||= [
        -> (item, options) do
          item[:label] = self.replace_blocks item[:label]
        end,
        -> (item, options) do
          item[:label] = item.inspect if options[:inspect_mode]
        end,
        -> (item, options) do
          item[:label] = "** #{item[:label]} **" if item[:marked]
        end,
        -> (item, options) do
          if item[:key].is_a? Array
            item[:label] = "> #{item[:label]}"
          elsif item[:key].is_a? Symbol
            item[:label] = ": #{item[:label]}"
          else
            item[:label] = "  #{item[:label]}"
          end
        end
      ]
    end

    def items_mangle
      @items_mangle ||= [
        -> (items, options) do
          items.sort_by { |i| i[:order] || 50 }
        end
      ]
    end

    def process_labels items, options = {}
      items = items.dup
      items_mangle.map { |pr| items = pr.call items, options }
      items.map { |item| item_mangle.inject(item) { |_item, pr| _item.dup.tap { |_i| pr.call _i, options } } }
    end

  end
end
