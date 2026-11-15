---
title: "Papercraft Update: New Version, New Website"
layout: article
---

I've been working quite a bit on Papercraft these last few weeks. Yesterday I
released Papercraft version 2.16, and here are some of the notable changes
introduced since the last update:

- Emit `DOCTYPE` for `html` tag by default. Before this change, you needed to
  use the `html5` tag to include the `DOCTYPE` at the top of the generated
  markup. Now you can just use `html`. This is important since this way you
  avoid [quirks mode](https://en.wikipedia.org/wiki/Quirks_mode).
- Do not content of `style` and `script` tags. This makes it easier to write
  inline CSS and Javascript.
- Add `Papercraft.markdown_doc` convenience method which returns a
  `Kramdown::Document` instance for further processing of Markdown content.
- Add support for rendering of namespaced components, so you can now do stuff
  like `Foo::Bar('baz')` right in your templates.

## New Papercraft Website

I've also been working on a website for Papercraft and it's finally online. Check it out:

[papercraft.noteflakes.com](https://papercraft.noteflakes.com){:target="_blank"}

Like the noteflakes.com website, which you're currently reading, the Papercraft
website is made using [Syntropy](https://github.com/digital-fabric/syntropy).
All of the documentation pages are written using Markdown. Let's look at some
examples of how Papercraft is used on its own website:

## The Default Layout

Here is the content of the default layout ([source code](https://github.com/noteflakes/noteflakes.com/blob/main/sites/papercraft.noteflakes.com/_layout/default.rb){:target="_blank"}):

```ruby
export template { |page_title: nil, **props|
  html {
    head {
      title(page_title ? "Papercraft - #{page_title}" : 'Papercraft - Functional HTML Templating for Ruby')
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
    }
    body {
      render_children(**props)
    }
    auto_refresh_watch!
  }
}
```

It's all pretty standard except for that `export` at the top, which means that
this file is loaded by Syntropy as a Syntropy module (more on that later).
There's also the `auto_refresh_watch!` directive, which is a Syntropy extension
that permits refreshing the page automatically whenever the source code changes
in development mode.

## The Docs Layout

The documentation page layout ([source
code](https://github.com/noteflakes/noteflakes.com/blob/main/sites/papercraft.noteflakes.com/_layout/docs.rb){:target="_blank"})
is a bit more involved, bit basically it is *derived* from the default layout
using `apply`:

```ruby
DefaultLayout = import '_layout/default'
Pages = import '_pages'

export DefaultLayout.apply { |entry:, pages:, href:, **props|
  header { ... }
  main {
    ...
    sidebar { ... }
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
    }
  }
}
```

I've omitted the header and the side bar for the sake of brevity, so let's look
at the `article` element which contains the actual content of the page. There's
the title, there's the pre-rendered HTML rendered from the Markdown content (but
you can just as well use the `markdown` method to render it in-place), and then
the `nav` element holds links to the previous and next pages. You can see how
the logic flows naturally along the HTML content expressed with plain Ruby.

Here's the code that renders the documentation pages ([source code](https://github.com/noteflakes/noteflakes.com/blob/main/sites/papercraft.noteflakes.com/docs%2B.rb){:target="_blank"}):

```ruby
Layout = import '_layout/docs'
Pages = import '_pages'

export ->(req) {
  href = req.path
  entry = Pages[href]
  if entry
    html = Layout.render(page_title: entry[:title], pages: Pages, href:, entry:)
    req.respond(html, 'Content-Type' => Qeweney::MimeTypes[:html])
  else
    raise Syntropy::Error.not_found
  end
}
```

The page entry is retrieved from the `Pages` collection, and then passed to the layout template, along with some other metadata.

## The Landing Page

The landing page (a.k.a. the *index* page) also uses the apply method to fill
the default layout with content. Here's a part of it ([source code](https://github.com/noteflakes/noteflakes.com/blob/main/sites/papercraft.noteflakes.com/index.rb){:target="_blank"}):

```ruby
Pages = import '_pages'
Layout = import '_layout/default'

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
            -> {
              h1 "Hello from Papercraft!"
            }.render
            ```
          MD
        }
        links {
          a "Documentation", href: Pages.default_href
          a "Source Code", href: "https://github.com/digital-fabric/papercraft", target: "_blank"
        }
      }
      hr
      ...
    }
  }
}
```

As you can see, we can mix HTML and Markdown content freely. Another thing that
may stick out is the fact that I (almost) don't use any CSS classes. I prefer
using semantic tag names, which not only makes the templates much more readable,
but also makes the generated HTML much smaller in size, which helps in creating a
snappy user experience.

## Refactoring Opportunities

For the Papercraft site, since there are basically just two kinds of layouts,
with little in common (except for the outer HTML envelope), I didn't really feel
there was a need to create components. But this possibility always exists. For
example, let's look at another snippet from the landing page:

```ruby
...
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
  ...
}
```

There are a total of six "featurettes" like that on the landing page, so
supposing we wanted to create a featurette component, it might look like this:

```ruby
Featurette = ->(href:, title:, text:) {
  a(href:) {
    h4 title
    p text
  }
}
```

And then the landing page markup would look as follows:

```ruby
...
features {
  Featurette(
    href: "/docs/01-introduction/01-overview",
    title: "Easy to write & read",
    text: "
      Write your HTML templates in plain Ruby. Use beautiful
      syntax for generating HTML.
    "
  )

  Featurette(
    href: "/docs/03-template-composition/01-component-templates",
    title: "Layouts & Components",
    text: "
      Compose and reuse your templates for layouts,
      components and partials.
    "
  )
}
```

I think from the point of view of effort vs gain it's not so interesting to do
this, but this is certainly a possibility, and just goes to show how easy it is
to compose and reuse templates in Papercraft.

## Integration with Other APIs

Another thing that occurred to me while working on the Papercraft website is
that in fact a lot of the difficulties or issues surrounding the integration of
a templating library with existing frameworks or tools just disappear with
Papercraft. There's no boilerplate code, no ceremony around setting up state or
context objects. Your templates become pure functions that take some parameters
as input, and give you back HTML code, ready to serve. And, did I mention it's
[really fast](https://papercraft.noteflakes.com/docs/05-papercraft-internals/01-how-papercraft-works)?

Please feel free to test-drive Papercraft in your projects. Head on over to the
[Papercraft website](https://papercraft.noteflakes.com/), and enjoy!