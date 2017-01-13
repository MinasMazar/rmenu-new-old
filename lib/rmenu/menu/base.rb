
module RMenu
  module Menu
    SEPARATOR = [ { label: "----------", key: nil } ]
    CONFIG = [
      { label: "=> config", key: [
        { label: "add item", key: :add_item },
        { label: "mod item", key: :mod_item },
        { label: "del item", key: ":del_item " },
        { label: "mod conf", key: ":mod_conf" },
        { label: "load conf", key: ":load_config" },
        { label: "save conf", key: ":save_config" },
        { label: "edit conf", key: ":edit_file '~/.rmenu.yml'" },
        { label: "quit", key: :stop },
      ]}
    ]
    USEFUL_APPS = [
      { label: "Mozilla Firefox", key: "firefox" },
      { label: "Terminal", key: "xterm" },
    ]
    FALLBACK = [] + USEFUL_APPS + SEPARATOR + CONFIG
  end
end
