export template { |pages:, path:, entry:|
  html5 {
    head {
      title(entry ? "Papercraft - #{entry[:title]}" : 'Papercraft')
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
    }
    body {
      header {
        cols {
          sidebar {
            a(href: '/') {
              img src: '/assets/papercraft.png'
              h2 "Papercraft"
            }
          }
          top {
            h3 "Functional Templating for Ruby"
            links {
              a(href: "https://github.com/digital-fabric/papercraft", target: "_blank") {
                img src: "/assets/github.png", title: "GitHub"
              }
              label(id: "sidebar-menu-button", for: "sidebar-toggle") {
                img src: "/assets/more.png"
              }
            }
          }
        }
      }
      main {
        input id: "sidebar-toggle", name: "sidebar-toggle", type: "checkbox"
        cols {
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
          article {
            content {
              h1 entry[:title]
              raw entry[:html]
              nav {
                if entry[:prev]
                  a(href: entry[:prev][:href]) {
                    p "Previous page"
                    h2 entry[:prev][:title]
                  }
                else
                  span
                end
                if entry[:next]
                  a(href: entry[:next][:href]) {
                    p "Next page"
                    h2 entry[:next][:title]
                  }
                else
                  span
                end
              }
            }
            # headings {
            #   h2 'On this page'
            #   entry[:headings].each { |(title, id)|
            #     p { a title, href: "\##{id}" } 
            #   }
            # }
          }
        }
      }
    }
    auto_refresh_watch!
  }
}
