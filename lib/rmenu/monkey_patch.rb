
module RMenu
  module MonkeyPatch

    class ::String
      def to_query_s
        split(/\s+/).join("+")
      end
      def to_item
        { label: self, key: self }
      end
    end

  end
end
