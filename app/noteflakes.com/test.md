---
title: Testing Testing Testing
---

### Here's some dynamic content:

```ruby
# render: true
p Time.now
p "env:"
ul {
  @env.keys.sort.each { |k|
    li {
      span k
      span ' = '
      span @env[k]
    }
  }
}
```

### Some more Markdown
