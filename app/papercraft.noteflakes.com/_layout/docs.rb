DefaultLayout = import '/_layout/default'
Pages = import '../_pages'

dev_mode = @env[:dev_mode]

export DefaultLayout.apply { |entry:, pages:, href:, **props|
  header {
    cols {
      sidebar {
        a(href: '/') {
          img src: '/assets/papercraft.png'
          h2 "Papercraft"
        }
      }
      top {
        span
        links {
          a(href: "/docs")
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
              if c[:href] == href
                a c[:title], href: c[:href], class: "current"
              else
                a c[:title], href: c[:href]
              end
            }
          }
        }
      }
      article {
        content {
          h1 entry[:title]
          raw entry[:html]
          if dev_mode
            p {
              a "Edit this file", href: "vscode://file/#{entry[:path]}"
            }
          end
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
