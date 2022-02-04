---
title: What's new in Polyphony - July 2021 edition
layout: article
---
Following [last month's update](/articles/2021-06-25-polyphony-june-edition), here's an update on the latest changes to Polyphony:

- Redesigned tracing system
- New methods for changing fiber ownership
- Support for appending to buffers when reading
- Improved backend statistics
- Improved control over reading with `#read` and `#readpartial`

## Redesigned tracing system

In previous versions, Polyphony included extensions to the core Ruby [TracePoint](https://rubyapi.org/3.0/o/tracepoint) API, so that events such as switching fibers, scheduling fibers, polling for I/O completions, could be traced using the same TracePoint API that's used for tracing method calls, variable access etc. In Polyphony 0.59 the tracing system was completely overhauled and separated from TracePoint. Polyphony backend events can now be traced by calling `Backend#trace_proc`:

```ruby
Thread.backend.trace_proc = proc { |*event| p event }
```

Events are fed to the tracing proc as plain Ruby arrays, where the first member signifies the type of event. Currently the following events are emitted:

```ruby
[:fiber_create, fiber]
[:fiber_schedule, fiber, resume_value, is_priority]
[:fiber_switchpoint, current_fiber]
[:fiber_run, fiber, resume_value]
[:fiber_event_poll_enter, current_fiber]
[:fiber_event_poll_leave, current_fiber]
```

## New methods for changing fiber ownership

Polyphony follows the [structured concurrency](https://en.wikipedia.org/wiki/Structured_concurrency) paradigm, where the lifetime of each fiber is limited to that of the fiber from which it was spun. This mechanism, also called a parent-child relationship, permits developers to spin up thousands of fibers in a structured and controlled manner. Version 0.60 introduces two new methods which allow you to change the parent of a fiber.

`Fiber#detach` sets the fiber's parent to the main fiber. This method could be useful if you need a fiber to outlive its parent:

```ruby
parent = spin do
  child = spin do
    do_something
  end
  child.detach
  child.parent #=> Fiber.main
end

parent.await
# parent is dead, but child is still alive!
```

`Fiber#attach` lets you set the fiber's parent to any other fiber, which might be useful if you start a fiber in some context but then need it to be limited by the lifetime of another fiber:

```ruby
worker_parent = spin { sleep }

fiber_maker = spin_loop do
  job = receive
  worker = spin { perform(job) }
  worker.attach(worker_parent)
end

# at some point we want to stop all workers
worker_parent.terminate # boom, all workers are terminated
```

## Support for appending to buffers when reading

Up until now, the backend read/recv APIs allowed you to provide a buffer and read into it, replacing any content it may hold. A major change introduced in version 0.60 allows reading to any position in the provided buffer, including appending to the buffer. The `Backend#read` and `Backend#recv` methods now accept a `buffer_pos` argument:

```ruby
# append to a buffer
i, o = IO.pipe

spin do
  o << 'foo'
  o << 'bar'
  o << 'baz'
end

buffer = +''
# buffer_pos is the last argument. -1 denotes the end of the buffer
Polyphony.backend_read(i, buffer, 3, false, -1)
buffer #=> 'foo'
Polyphony.backend_read(i, buffer, 3, false, -1)
buffer #=> 'foobar'
Polyphony.backend_read(i, buffer, 3, false, -1)
buffer #=> 'foobarbaz'
```

This addition may seem minor but what it allows us to do, beyond not needing to concatenate strings, is to write parsers that are competely blocking. I'm currently writing a [custom HTTP/1 parser](https://github.com/digital-fabric/tipi/blob/master/ext/tipi/http1_parser.c) for Tipi that's based on this unique feature and which promises to significantly improve both throughput and memory usage. (I'll discuss this new parser in detail in another post.)

## Improved backend statistics

Polyphony version 0.61 has introduced streamlined and more comprehensive backend statistics, now accessible using `Backend#stats`. The statistics are returned as a hash with the following keys:

- `:runqueue_size`: the size of the run queue
- `:runqueue_length`: the number of fibers currently in the runqueue
- `:runqueue_max_length`: the max number of fibers in the runqueue since the last call to `#stats`
- `:op_count`: the number of backend operations since the last call to `#stats`
- `:switch_count`: the number of fiber switches since the last call to `#stats`
- `:poll_count`: the number of times the backend polled for completions since the last call to `#stats`
- `:pending_ops`: number of operations currently pending

## Improved control over reading with `#read` and `#readpartial`

Finally, Polyphony versions 0.63 and 0.64 have added optional arguments to `IO#read` and `IO#readpartial` in order to allow developers to have more flexibility and to use the new "append to buffer" feature discussed above. Here are the updated signatures for those methods (they apply also to all socket classes):

- `IO#read(len = nil, buf = nil, buf_pos = 0)`
- `IO#readpartial(len, str = +'', buffer_pos = 0, raise_on_eof = true)`

Note the `raise_on_eof` argument, which can be used to control whether `#readpartial` raises an `EOFError` when an EOF is encountered.

## What's next for Polyphony

As I wrote above, I'm currently developing a [custom HTTP/1 parser](https://github.com/digital-fabric/tipi/blob/master/ext/tipi/http1_parser.c) for Tipi, which already has promising performance characteristics, reduces dependencies and is completely synchronous (i.e. no callbacks are involved). I hope to be able to switch Tipi to using the new parser in the coming weeks and having it battle tasted in one of my production projects, and then to continue to write a HTTP/2 parser with a similar design.
