
module RMenu
  module Util
    module Methods

      def to_query_search(str)
        str = str.split(/\s+/) if str.is_a? String
        str.join("+")
      end

    end
  end
end
