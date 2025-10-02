---
title: Extending Papercraft
---

Papercraft can be extended by defining custom method calls that are accessible
from any template. This is done with `Papercraft.extension`:

```ruby
Papercraft.extension(
  youtube_player: ->(ref, width: 560, height: 315) {
    iframe(
      width:, height:,
      src: "https://www.youtube-nocookie.com/embed/#{ref}"
    )
  },
  ulist: ->(list) {
    ul {
      list.each { li { render_yield it } }
    }
  }
)

# usage:
->(youtube_video_refs) {
  ulist(youtube_video_refs) {
    youtube_player(it)
  }
}
```

