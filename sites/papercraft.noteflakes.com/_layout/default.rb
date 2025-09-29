export template { |pages:, path:, entry:|
  html5 {
    body {
      style <<~CSS
        header {
          display: block;
          height: 3em;
        }

        container {
          display: grid;
          grid-template-columns: 12em 1fr;
        }
      CSS
      header {
        
      }
      container {
        sidebar {
          pages.root[:children].each_value {
            h2 it[:title]
            it[:children].each_value { |c|
              p {
                a c[:title], href: c[:href]
              }
            }
          }
        }
        content {
          markdown entry[:markdown]
        }
      }
    }
    auto_refresh_watch!
  }
}
