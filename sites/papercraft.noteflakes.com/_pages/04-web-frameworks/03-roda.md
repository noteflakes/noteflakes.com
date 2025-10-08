---
title: Roda on Papercraft
---

The [roda-papercraft](https://github.com/digital-fabric/roda-papercraft) Roda
plugin adds some methods to let you render
[Papercraft](https://papercraft.noteflakes.com/) templates in your Roda app.
This plugin lets you either define templates inline inside your Roda router, or
load templates from files. This repository includes an example directory with an
example Roda app showing typical use.

To use Papercraft with Roda, do the following:

### 1. Add roda-papercraft to your App

In your `Gemfile`, add the following line:

```ruby
gem "roda-papercraft"
```

### 2. Activate the Papercraft Plugin

In your Roda app, load roda-papercraft:

```ruby
require "roda-papercraft"
```

Then load the plugin inside your app:

```ruby
class App < Roda
  plugin :papercraft
  ...
end
```

By default, the template root is `"templates"` (relative to the working
directory). To change the template root, you can configure the plugin:

```ruby
class App < Roda
  plugin :papercraft
  ...
end
```

## Rendering Templates from Files

Your template files are normal Ruby source files. Each file should contain a
single lambda. Here's an example:

```ruby
# templates/hello.rb
-> {
  h1 "Hello from Papercraft"
}
```

To render the template, first load it using the `#template` method, and then run
`#render` on it:

```ruby
route do |r|
  r.get "hello" do
    template("hello").render
  end

  ...
end
```

If the template takes arguments, you can pass them through the `#render` call:

```ruby
# templates/greet.rb
->(name) {
  h1 "Hello, #{name}!"
}

# in your app
route do |r|
  r.get "greet", String do |name|
    template("greet").render(name)
  end
  ...
end
```

## Rendering Templates Inline

To render templates inline, just use `#render` directly.

```ruby
route do |r|
  r.get "hello" do
    render {
      h1 "Hello from Papercraft"
    }
  end
end
```