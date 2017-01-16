require "yaml"

module RMenu
  module Menu
    EXAMPLE_CONF = File.expand_path "../../../../assets/example-conf.yml", __FILE__
    # Profile definition::
    # FALLBACK = {
    #   name: "fallback",
    #   type: :fallback,
    #   position: :top,
    #   lines: 15,
    #   case_insensitive: true,
    #   background: "#334433",
    #   foreground: "#00FF33",
    #   selected_background: "#449955",
    #   selected_foreground: "#00FF33",
    #   items: [
    #     { label: "=> config", key: [
    #       { label: "add item", key: :add_item },
    #       { label: "mod item", key: :mod_item },
    #       { label: "del item", key: ":del_item " },
    #       { label: "mod conf", key: ":mod_conf" },
    #       { label: "load conf", key: ":load_conf" },
    #       { label: "save conf", key: ":save_conf" },
    #       { label: "edit conf", key: ":edit_file '~/.rmenu.yml'" },
    #       { label: "quit", key: :stop },
    #     ], order: 1 },
    #     { label: "----------", key: nil, order: 2 },
    #     { label: "Mozilla Firefox", key: "firefox" },
    #     { label: "Terminal", key: "xterm" },
    #   ]
    # }
    FALLBACK = YAML.load_file(EXAMPLE_CONF)[:profiles][:main]
  end
end
