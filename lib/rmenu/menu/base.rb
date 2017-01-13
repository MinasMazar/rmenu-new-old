
module RMenu
  module Menu
    BASE = [
      { label: "Exec firefox", key: "firefox" },
      { label: "Exec Chromium", key: "chromium" },
      { label: "Search on Clojure Docs", key: "https://clojuredocs.org/search?q=__Search on Clojure Docs__" },
      { label: "Take screenshot (Dropbox)", key: "i3-scrot" },
      { label: "Search on wiki", key: "https://it.wikipedia.org/w/index.php?search=__SEARCH ON WIKI__"},
      { label: "rmenu.config => ", key: [
        { label: "Create item", key: :add_item },
        { label: "Quit", key: :stop }
      ]}
    ]
  end
end
