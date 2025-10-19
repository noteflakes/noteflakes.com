---
title: CHANGELOG
---

# 3.0.0 2025-10-19

- Improve implementation of `Papercraft.apply`
- Add support for rendering self-closing XML tags
- Streamline Papercraft API
- Add support for `Papercraft.render { ... }`
- Prefix internal Proc extensions with `__papercraft_`
- Change API to use `Papercraft.html` instead of `Proc#render`. Same for
  `apple`, `render_xml` etc.

# 2.24 2025-10-14

- Update gem links
- Simplify `render_cache`, caller must provide cache key
- Reduce surface area of Proc extensions

# 2.23 2025-10-12

- Update ERB to version 5.1.1

# 2.22 2025-10-08

- Use `prepend` instead of `include` to extend the `Proc` class

# 2.21 2025-10-08

- Fix `Proc#apply` parameter handling
- Put Proc extensions in separate module, included into Proc

# 2.20 2025-10-08

- Raise error on void element with child nodes or inner text
- Fix compilation of empty template

# 2.19 2025-10-08

- Use gem.coop in Gemfile

# 2.18 2025-10-08

- Add `link_stylesheet` extension
- Add support for rendering templates in IRB
- Update Sirop to 1.0

# 2.17 2025-10-05

- Update dependencies
- Add support for attributes in `html` tag
- Add `Papercraft.__clear__extensions__` method

# 2.16 2025-10-02

- Add support for namespaced components

# 2.15 2025-10-01

- Add `Papercraft.markdown_doc` method
- Emit DOCTYPE for `#html` as well as `#html5`

# 2.14 2025-09-17

- Do not escape inner text of style and script tags

# 2.13 2025-09-11

- Pass level to HTML debug attribute injection proc

# 2.12 2025-09-11

- Add support for injecting location attributes into HTML tags (for debug purposes)

# 2.11 2025-09-11

- Add mode param to `Papercraft::Template` wrapper class

# 2.10 2025-09-11

- Add support for rendering XML, implement `Proc#render_xml`
- Fix handling of literal strings with double quotes
- Improve error handling for `Papercraft::Error` exceptions

# 2.9 2025-09-02

- Tweak generated code to incorporate @byroot's
  [recommendations](https://www.reddit.com/r/ruby/comments/1mtj7bx/comment/n9ckbvt/):
  - Remove call to to_s coercion before calling html_escape
  - Chain calls to `#<<` with emitted HTML parts

# 2.8 2025-08-17

- Add `#render_children` builtin
- Rename `#emit_yield` to `#render_yield`
- Add `Proc#render_cached` for caching render result

# 2.7 2025-08-17

- Improve source maps and whitespace in compiled code
- Minor improvements to emit_yield generated code
- Add support for extensions

# 2.6 2025-08-16

- Add support for block invocation

# 2.5 2025-08-15

- Translate backtrace for exceptions raised in `#render_to_buffer`
- Improve display of backtrace when source map is missing entries
- Improve handling of ArgumentError raised on calling the template
- Add `Template#apply`, `Template#compiled_proc` methods

# 2.4 2025-08-10

- Add Papercraft::Template wrapper class

# 2.3 2025-08-10

- Fix whitespace issue in visit_yield_node
- Reimplement and optimize exception backtrace translation
- Minor improvement to code generation

# 2.2 2025-08-09

- Update docs
- Refactor code

# 2.1 2025-08-08

- Optimize output code: directly invoke component templates instead of calling
  `Papercraft.render_emit_call`. Papercraft is now
- Optimize output code: use separate pushes to buffer instead of interpolated
  strings.
- Streamline API: `emit proc` => `render`, `emit str` => `raw`, `emit_markdown`
  => `markdown`
- Optimize output code: add `frozen_string_literal` to top of compiled code
- Add more benchmarks (#1)
- Optimize output code: use ERB::Escape.html_escape instead of CGI.escape_html
  (#2)
- Fix source map calculation

## 2.0.1 2025-08-07

- Fix source map calculation

## 2.0 2025-08-07

- Passes all HTML, compilation tests from Papercraft
- Automatic compilation
- Plain procs/lambdas as templates
- Remove everything not having to do with HTML
- Papercraft: compiled functional templates - they're super fast!