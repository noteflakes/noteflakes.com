Pages = import './_pages'
Layout = import '/_layout/default'

export Layout.apply {
  main {
    single {
      hero {
        logo {
          img src: "/assets/papercraft.png"
        }
        h1 {
          span "Papercraft"
        }
        h2 "Functional HTML Templating for Ruby"
        snippet {
          markdown <<~MD
            ```ruby
            Papercraft.html {
              h1 "Hello from Papercraft!"
            }
            ```
          MD
        }
        links {
          a "Documentation", href: Pages.default_href
          a "Source Code", href: "https://github.com/digital-fabric/papercraft", target: "_blank"
        }
      }
      hr
      features {
      a(href: "/docs/01-introduction/01-overview") {
          markdown <<~MD
            #### Easy to write & read
            
            Write your HTML templates in plain Ruby. Use beautiful
            syntax for generating HTML.
          MD
        }

        a(href: "/docs/03-template-composition/01-component-templates") {
          markdown <<~MD
            #### Layouts & Components
            
            Compose and reuse your templates for layouts,
            components and partials.
          MD
        }

        a(href: "/docs/02-basic-usage/01-writing-templates") {
          markdown <<~MD
            #### Functional Approach
            
            Papercraft's functional approach helps you write reusable,
            self-contained templates.
          MD
        }

        a(href: "/docs/05-papercraft-internals/01-how-papercraft-works") {
          markdown <<~MD
            #### Fast Rendering
            
            Enjoy best-in-class performance using Papercraft's optimizing
            compiler.
          MD
        }

        a(href: "/docs/04-web-frameworks/01-hanami") {
          markdown <<~MD
            #### Web Framework Integration
            
            Use Papercraft with your favorite web framework: Hanami, Roda, and
            coming soon: Rails.
          MD
        }

        a(href: "/docs/02-basic-usage/03-HTML-elements") {
          markdown <<~MD
            #### Security by Default
            
            Prevent cross-site scripting attacks with Papercraft's
            automatic HTML escaping.
          MD
        }
      }
    }
  }
}
