
module RMenu
  module Menu
    SEPARATOR = [ { label: "----------", key: nil } ]
    CONFIG = [
      { label: "=> config", key: [
        { label: "add item", key: :add_item },
        { label: "mod item", key: :mod_item },
        { label: "del item", key: ":del_item " },
        { label: "load config", key: ":load_config" },
        { label: "save config", key: ":save_config" },
        { label: "edit config", key: ":edit_file '~/.rmenu.yml'" },
        { label: "quit", key: :stop },
      ], order: 90 }
    ]
    USEFUL_APPS = [
      { label: "Exec firefox", key: "firefox" },
      { label: "Exec Chromium", key: "chromium" },
      { label: "Search on Clojure Docs", key: "https://clojuredocs.org/search?q=__Search on Clojure Docs__" },
      { label: "Take screenshot (Dropbox)", key: "i3-scrot" },
      { label: "Search on wiki", key: "https://it.wikipedia.org/w/index.php?search=__SEARCH ON WIKI__"},
    ]
    MAIN = [] + USEFUL_APPS + SEPARATOR + CONFIG
  end
end
