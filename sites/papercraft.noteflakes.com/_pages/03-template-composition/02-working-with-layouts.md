---
title: Working with Layouts
---

Layouts are central to efficiently generating HTML in web apps. Papercraft makes
layouts easy to implement and use. In most situations, layout templates will
generate the outer envelope of a web page - the `html` tag, the `head` and
`body` tags, and also the different tags inside the `head` tag. We can define
additional tag inside the `body` tag, and eventually call `render_children` to
render whatever block is passed to the layout template upon rendering:

```ruby
DefaultLayout = ->(**props) {
  html {
    head {
      title("My super website")
      link(rel: "icon",       type: "image/png", href: "/assets/icon.png")
      link(rel: "stylesheet", type: "text/css",  href: "/assets/style.css")
    }
    body {
      render_children(**props)
    }
  }
}
```

To use the above layout template, we call `DefaultLayout.render` with a block
containing the page content:

```ruby
DefaultLayout.render {
  h1 "My title"
  article {
    p "My article"
    ...
  }
}
```

> The layout template takes keyword arguments (`**props`) and passes them to the
> given block. This way, whatever parameters are passed to the layout, we pass
> in turn to the inner template. It is useful to look at this practice as a
> convention and to design your templates to always take keyword arguments.

## Creating Derived Layouts

Another way to use layout templates is by creating derived templates using the
`apply` method. This technique is useful for creating specialized layouts. For
example, you'll want to take the default template and add additional markup
inside the body for displaying articles:

```ruby
ArticleLayout = DefaultLayout.apply { |**props|
  article {
    h1 props[:title]
    markdown props[:content]
  }
}

ArticleLayout.render(
  title: "My title",
  content: "My article content"
)
```
