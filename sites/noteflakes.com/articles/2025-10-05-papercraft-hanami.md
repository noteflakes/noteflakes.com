---
title: "Hanami on Papercraft"
layout: article
---

Lately I've been really excited about Papercraft and the possibilities it brings
to developing web apps with Ruby. Frankly, the more I use it, the more I see how
simple and joyful it can be to write beautiful HTML templates in plain Ruby.

Now that the [Papercraft website](https://papercraft.noteflakes.com/) is up, I'd
like to concentrate on making it easier for everyone to use Papercraft in their
apps, whatever their web framework. So this is exactly what I set out to do this
weekend. First on my list: [Hanami](https://hanamirb.org/), an established Ruby
web framework with a substantial following.

Since I never used Hanami, I decided to follow the [Getting Started
guide](https://guides.hanamirb.org/v2.3/introduction/getting-started/) and then
started to peek under the hood to see how I could replace the ERB templates with
Papercraft ones.

After a few hours and a quite a bit of fiddling, I had a working proof of
concept. I then proceeded to extract the code into a new gem I'm releasing today called [hanami-papercraft](https://github.com/digital-fabric/hanami-papercraft).

To use it, do the following:

## 1. Add hanami-papercraft

In your `Gemfile`, add the following line:

```ruby
gem "hanami-papercraft"
```

Then run `bundle install` to update your dependencies.

### 2. Set your app's basic view class 

In `app/view.rb`, change the `View` classes superclass to `Hanami::PapercraftView`:

```ruby
# app/view.rb

module Bookshelf
  class View < Hanami::PapercraftView
  end
end
```

### 3. Use a Papercraft layout template

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

### 4. Use Papercraft view templates

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

That's it for now. There's probably a lot of stuff that won't work. If you run into any problems, please let me know. I'll gladly accept contributions in the form of bug reports or PR's. Just head on over to the [hanami-papercraft](https://github.com/digital-fabric/hanami-papercraft) repo...
