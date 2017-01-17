
module RMenu
  module LabelMangle

    def item_mangle
      @item_mangle ||= [
        -> (item, conf) do
          item[:label] = item.inspect if conf[:inspect_mode]
        end,
        -> (item, conf) do
          item[:label] = "** #{item[:label]} **" if item[:marked]
        end,
        -> (item, conf) do
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
        -> (items, conf) do
          items.sort_by { |i| i[:order] || -50 }
        end
      ]
    end

    def process_labels items, conf = self.conf
      items = items.dup
      items_mangle.inject(items) { |_items, pr| pr.call _items, conf}
      items.map { |item| item_mangle.inject(item) { |_item, pr| _item.dup.tap { |_i| pr.call _i, conf } } }
    end

  end
end
