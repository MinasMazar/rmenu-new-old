
module RMenu
  module Profiles
    FALLBACK = {
      main: {
        items: [
          { label: "=> config", key: [
            { label: "add item", key: :add_item },
            { label: "mod item", key: :mod_item },
            { label: "del item", key: ":del_item " },
            { label: "mod conf", key: ":mod_conf" },
            { label: "load conf", key: ":load_conf" },
            { label: "save conf", key: ":save_conf" },
            { label: "edit conf", key: ":edit_file '~/.rmenu.yml'" },
            { label: "quit", key: :stop },
          ], order: 1 },
          { label: "----------", key: nil, order: 2 },
          { label: "Mozilla Firefox", key: "firefox" },
          { label: "Terminal", key: "xterm" },
        ]
      }
    }
  end
end
