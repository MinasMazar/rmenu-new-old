
module RMenu
  module Menu

    module BuiltIn
      def separator
        { label: "------------", key: nil }
      end
      def create_submenu(label)
        {
          label: label,
          key: [
            {label: "Populate!", key: ":add_item nil, current_menu", order: 1, implode: true },
            {label: "Fix!", key: ":current_menu.reject! { |i| i[:implode] } ", order: 1, implode: true },
            separator.merge({implode: true})
          ],
          keep_open: true
        }
      end
      def always_visible_items
        [
          { label: "------------", key: nil },
          {label: "<-- BACK", key: :back, order: 90 }
        ]
      end
    end

  end
end
