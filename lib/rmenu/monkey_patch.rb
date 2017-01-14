
module RMenu
  module MonkeyPatch

    class ::String
      def to_query_s
        split(/\s+/).join("+")
      end
    end

  end
end
