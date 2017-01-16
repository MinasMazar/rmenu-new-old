
module RMenu
  module Menu

    module BuiltIn
      def separator
        { label: "------------", key: nil }
      end
      def populator_combo
        [
          {label: "Populate!", key: Proc.new { add_item nil, current_menu }, order: 1, implode: true },
          {label: "Fix!", key: Proc.new { current_menu.reject! { |i| i[:implode] } }, order: 1, implode: true },
          separator.merge({implode: true})
        ]
      end
    end

  end
end
