---
title: Introducing UringMachine
layout: article
---

[UringMachine](https://github.com/digital-fabric/uringmachine) is a new Ruby gem
for performing concurrent I/O using io_uring and Ruby fibers. In UringMachine
I've implemented all the lessons I've learned from my previous attempts at
bringing io_uring to Ruby:
[Polyphony](https://github.com/digital-fabric/polyphony), a comprehensive gem
providing io_uring functionality, structured concurrency, and monkey-patching
for the Ruby standard library; and [IOU](https://github.com/digital-fabric/iou),
a low level async API for using io_uring from Ruby.

Here are some of those lessons:

## Monkey-patching

I've defended monkey-patching before, but my stance now is more nuanced.
Frankly, it's a big pain to maintain, because the Ruby stdlib is evolving, and
in some cases it's really an excercise in futility. So, UringMachine doesn't
really touch the standard IO classes, it just doesn't use them. UringMachine
works with plain file descriptors:

```Ruby
require 'uringmachine'

machine = UM.new
fd = machine.open('foo.bar', UM::O_RDONLY)
buf = +''
ret = machine.read(fd, buf, 1 << 16)
puts "read #{ret} bytes: #{buf.inspect}"
machine.close(fd)
```

Now, at first sight this might look like a really clumsy way to do I/O in Ruby,
but there's more than meets the eye in the above example. A second example will
make things a bit clearer:

```Ruby
filenames = ['foo.bar', 'bar.baz', 'baz.foo']
content_map = {}

MAX_READ_LEN = 65536

# A neat abstraction to do what IO.read(fn) does
def read_file(machine, fn)
  fd = machine.open(fn, UM::O_RDONLY)
  buf = +''
  loop do
    # the -1 means append to buffer
    ret = machine.read(fd, buf, MAX_READ_LEN, -1)
    return buf if ret < MAX_READ_LEN
  end
ensure
  machine.close(fd) if fd
end

fibers = filenames.map do |fn|
  machine.spin do
    content_map[fn] = read_file(fn)
  rescue SystemCallError
    puts "Failed to read #{fn}"
  end
end
machine.join(*fibers)
p content_map: content_map
```

So yes it's much lower level than IO's `#read` and `#write` methods, but what we
gain here is easy launching of concurrent (a.k.a. asynchronous) operations. In
the above example, three files are read concurrently in three separate fibers by
calling `#spin` (just like in Polyphony). Each fiber opens the given filename,
reads the contents until EOF and then puts the content in a content map.
Meanwhile the main fiber calls `#join` in order to wait for the three spun
fibers to terminate.
