---
title: Hanami on Papercraft
---

The [hanami-papercraft](https://github.com/digital-fabric/hanami-papercraft) gem provides support for using Papercraft templates in Hanami apps. To use it, follow these steps:

## 1. Add hanami-papercraft to Your App

In your `Gemfile`, add the following line:

```ruby
gem "hanami-papercraft"
```

Then run `bundle install` to update your dependencies.

## 2. Set your app's basic view class 

In `app/view.rb`, change the `View` classes superclass to `Hanami::PapercraftView`:

```ruby
# app/view.rb

module Bookshelf
  class View < Hanami::PapercraftView
  end
end
```

## 3. Use a Papercraft layout template

Replace the app's layout template stored in `app/templates/layouts/app.html.erb`
with a file named `app/templates/layouts/app.papercraft.rb`:

```ruby
# app/templates/layouts/app.papercraft.rb

->(config:, context:, **props) {
  html(lang: "en") {
    head {
      meta charset: "UTF-8"
      meta name: "viewport", content: "width=device-width, initial-scale=1.0"
      title "Bookshelf"
      favicon_tag
      stylesheet_tag(context, "app")
    }
    body {
      render_children(config:, context:, **props)
      javascript_tag(context, "app")
    }
  }
}
```

## 4. Use Papercraft view templates

You can now start writing your view templates with Papercraft, e.g.:

```ruby
# app/templates/books/index.papercraft.rb

->(context:, books:, **props) {
  h1 "Books"

  ul {
    books.each do |book|
      Kernel.p book
      li book[:title]
    end
  }
}

```

## Passing Template Parameters

While theoretically you have access to the view class in your templates (through
`self`), you should use explicit arguments in your templates, as shown in the
examples above. The `PapercraftView` class always passes template parameters as
keyword arguments to the layout and the view templates.

In the view template above, the `books` keyword argument is defined because the
view class exposes such a parameter:

```ruby
# app/views/books/index.rb

module Bookshelf
  module Views
    module Books
      class Index < Bookshelf::View
        expose :books do
          [
            {title: "Test Driven Development"},
            {title: "Practical Object-Oriented Design in Ruby"}
          ]
        end
      end
    end
  end
end
```

