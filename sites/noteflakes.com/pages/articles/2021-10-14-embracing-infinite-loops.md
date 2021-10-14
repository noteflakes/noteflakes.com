---
title: "Embracing Infinite Loops with Ruby and Polyphony"
date: 2021-10-14
layout: article
---

In this article I'll discuss the use of infinite loops as a major construct when
writing concurrent apps in Ruby using Polyphony. I'll show how infinite loops
differ from normal, finite ones; how they can be used to express long-running
tasks in a concurrent environment; and how they can be stopped.

> [Polyphony](https://github.com/digital-fabric/polyphony) is a library for
> writing highly concurrent Ruby apps. Polyphony harnesses Ruby fibers and a
> powerful [io_uring](https://unixism.net/loti/what_is_io_uring.html)-based I/O
> runtime to provide a solid foundation for building high-performance concurrent
> Ruby apps.

In the last few months I've been slowly transitioning from working on
Polyphony-designing APIs and adding functionality-to using to develop actual
applications, some of them [open source](https://github.com/digital-fabric), and
others closed source production apps for my clients.

In the process of actually using Polyphony as the basis for writing concurrent
apps, I've discovered some patterns that I'd like to share. It's really
fascinating how the design of an API can impact the patterns that emerge in the
application code. Take for example loops.

Developers that are used to asynchronous APIs will probably find the idea of
writing loops in your app code anathema to asynchronous design: there's only one
loop - the main event loop - and it is that loop which drives your code. You
just provide callbacks to be called at the right moment.

By contrast, with Polyphony the app code is written in a sequential style, and
it is the app code that is in control. There is *no* event loop. Instead, you
can create any number of fibers, all executing concurrently, with each of those
fibers proceeding independently of the others.

But loops come into play when you want to launch autonomous long-running tasks,
like for example listening for incoming connections on a TCP socket, pulling
items from a queue and processing them, or periodically running some background
task. Infinite loops are what makes it possible to "fire-and-forget" those
concurrent processes.

## Loops are everywhere!

Loops are one of the most useful ways to control execution. Loops are used
anywhere you need to repeat an operation, and can be expressed in a variety of
ways, from the lowly `GOTO`, through plain `for` and `while` loops, all the way
to Ruby's elegant `#each` and related methods, which take a block and apply it
to items from some *iterable* object. While those don't necessarily look like
loops, they are, in fact, loops:

```ruby
# this is a loop
while (item = queue.shift)
  item.process
end

# this is also a loop
queue.each { |i| i.process }
```

## Infinite loops

Inifinite loops are loops that run indefinitely. A loop can be inadvertently
infinite if the loop logic is faulty, but loops can also be infinite by design.
Infinite loops are made for running *autonomous*, *long-lived* tasks that can run
any number of iterations, and are not meant to be stopped *conditionally*. Here
are some examples:

```ruby
# Accept incoming connections:
loop do
  socket = server.accept
  handle_client_connection(socket)
end

# Process items from a queue:
loop do
  item = queue.shift
  process(item)
end
```

As the example above shows, Ruby provides the very useful `#loop` method which
lets us express infinite loops in a clear and concise manner. Looking at the
code we can immediately tell that we're dealing with an infinite loop.

What's important to note about infinite loops is that they *can* include a
mechanism for breaking out of the loop if a certain condition is met. In fact,
sometimes the distinction between a finite loop and an infinite one is not that
clear.

Take for example a loop for handling an HTTP client connection. It needs to run
for the life time of the connection, which can last for any duration and for any
number of HTTP requests. In this case, this might look like an infinite loop,
but it will include a conditional `break`:

```ruby
# using h1p for parsing HTTP/1
def handle_client_connection(socket)
  parser = H1P::Parser.new(socket)
  loop do
    headers = parser.parse_headers # returns nil when socket is closed
    break unless headers
    
    body = parser.read_body
    handle_request(headers, body)
  end
end
```

Another way to express the same logic, which makes it look like a normal finite
loop, is like this:

```ruby
def handle_client_connection(socket)
  parser = H1P::Parser.new
  while (headers = parser.parse_headers)
    body = parser.read_body
    handle_request(headers, body)
  end
end
```

## Concurrent infinite loops

What's interesting about infinite loops is that once they start, theoretically
they will go on forever! In Polyphony you can start any number of infinite
loops, each running in its own fiber. Polyphony does the hard work of switching
between all those fibers, letting each fiber proceed at its own pace once the
operation it was waiting for has completed: reading from or writing to a socket,
waiting for an item to become available on a queue, etc. To do this, we use the
`#spin` global method provided by Polyphony, which spins up new fibers:

```ruby
item_processor = spin do
  loop do
    item = item_queue.shift
    process(item)
  end
end

http_server = spin do
  server = TCPServer.new('0.0.0.0', 1234)
  loop do
    socket = server.accept
    # each client runs in its own fiber
    spin { handle_http_client(socket) }
  end
end

Fiber.await(item_processor, http_server)
```

In the above example, we start a fiber for processing items from a queue, and
along side it an HTTP server. Each of those is implemented using an infinite
loop running on a separate fiber. Finally, the main fiber waits for those two
fibers to terminate. While the main fiber waits, Polyphony takes care of running
the item processor and the HTTP server, with each fiber proceeding at its own
pace as items are pushed into the queue, and as incoming HTTP connections are
being accepted.

## Interrupting an infinite loop

As we saw above, starting an inifinite loop on a separate fiber is really easy,
but how do you interrupt one? Polyphony provides us with some tools for
interrupting fibers at any time. We can do that by scheduling the specific fiber
with an exception, which might be a normal exception, or one of the special
exceptions that Polyphony provides for controlling fibers.

In order to stop a fiber running an infinite loop, we can issue call
`Fiber#stop`:

```ruby
item_processor = spin do
  loop do
    item = item_queue.shift
    process(item)
  end
end

# tell the item_processor to stop
item_processor.stop

# then wait for it to terminate
item_processor.await
```

Under the hood, `Fiber#stop` schedules the fiber with a `Polyphony::MoveOn`
exception, which means that the fiber should just terminate at the earliest
occasion, without the exception bubbling further up the fiber hierarchy.

As the example above shows, telling a fiber to stop does not mean it will do so
immediately. We also need to properly wait for it to terminate, which we do by
calling `item_processor.await` or `Fiber.await(item_processor)`. As discussed
above, stopping a fiber is done by scheduling it with a special exception that
tells it to terminate. The terminated fiber will then proceed to terminate any
child fibers it has, and perform other cleanup. This also means that you can use
normal `ensure` blocks in order to perform cleanup. Let's rewrite our item
processor to process items by sending them in JSON format over a TCP connection:

```ruby
item_processor = spin do
  soket = TCPSocket.new(PROCESSOR_HOSTNAME, PROCESSOR_PORT)
  loop do
    item = item_queue.shift
    socket.puts item.to_json
  end
ensure
  socket.close
end
```

## More ways to stop a fiber

In addition to the `Fiber#stop` method, Polyphony has other APIs that can be
used to stop a fiber in a variety of ways, including by raising an exception in
the fiber's context, and gracefully terminating a fiber. Termnating a fiber with
an exception is done using `Fiber#raise`. This is especially useful when you
need to implement your own error states:

```ruby
my_fiber.raise(FooError, 'bar')
```

A graceful termination can be done using `Fiber#terminate` which takes an
optional boolean flag. This requires a bit more logic in the fiber itself:

```ruby
item_processor = spin do
  soket = TCPSocket.new(PROCESSOR_HOSTNAME, PROCESSOR_PORT)
  loop do
    item = item_queue.shift
    socket.puts item.to_json
  end
ensure
  if Fiber.current.graceful_shutdown?
    move_on_after(10) do
      wait_for_inflight_items
    end
  end
  socket.close
end

# terminate gracefully
item_processor.terminate(true)
```

In the example above, we added logic in the ensure block that waits up to 10
seconds for all inflight items to be processed, then proceeds with closing the
TCP socket.

(We'll take a closer look at exception handling and fiber termination in a
future article.)

## Polyphony is just plain Ruby

Looking at all the above examples, you will have noticed how the Polyphony API
looks baked into the Ruby language. One of my principal design goals was to
minimize boilerplate code when expressing concurrent operations. There's no
instantiating of special objects, no weird mechanisms for controlling fibers or
rescuing exceptions. It just looks like plain Ruby!

## Conclusion

In this article I've showed you how infinite loops can be used to express
long-running concurrent tasks using
[Polyphony](https://github.com/digital-fabric/polyphony). Polyphony provides all
the tools needed for controlling the execution of concurrent fibers. For more
information about Polyphony you can go to the [Polyphony
website](https://digital-fabric.github.io/polyphony/). You can also browse the
[examples](https://github.com/digital-fabric/polyphony/tree/master/examples) in
the Polyphony repository.