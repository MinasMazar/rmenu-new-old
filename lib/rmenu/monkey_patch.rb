
module RMenu
  module MonkeyPatch

    class ::Hash
      def to_item
        self
      end
    end
    class ::String
      def to_query_s
        split(/\s+/).join("+")
      end
      def to_item
        { label: self, key: self }
      end
    end

  end

  class Item < Hash
  end
end
