---
title: Exploring unix pipes with Ruby and Polyphony
layout: article
---

Most of you are probably familiar with the concept of pipes on Unix-like OSes.
We mostly encounter pipes on the command line, where we can use them to use one
command's output as another's input. But pipes can also be used programmtically.
On Linux specifically, pipes let us move data between two arbitrary file
descriptors, without the data ever being seen by our user-space program, and in
some cases without it even being copied at all. This is done using the
[`splice()`](https://man7.org/linux/man-pages/man2/splice.2.html) system call,
which we'll explore in more detail below.

In the last few weeks I've been working on adding some abstractions to
[Polyphony](https://github.com/digital-fabric/polyphony) that make it easier to
work with pipes and to use `splice()` to move data between arbitrary file
descriptors (which Rubyists know as `IO` instances.)

I have also added a few data compression/decompression APIs that can
significantly improve performance when working with compressed data, and remove
the allocation overhead involved when working with the `zlib` APIs in Ruby's
standard library. But let's start by discussing `splice()` and what it allows us
to do.

## How to use splice with Polyphony

Let's start with the basics: the `splice` system call (available only on Linux)
allows us to move data between two arbitrary file descriptors, without reading
it from the source fd, and then writing it to the target fd, which necessitates
moving data back and forth between the kernel and our user space program. If
you've read the above-linked man page for `splice()`, you'll have noticed that
`splice()` needs at least one of the given file descriptors to refer to a pipe.
As Linus Torvalds himself
[explains](https://yarchive.net/comp/linux/splice.html):

> The pipe is just the standard in-kernel buffer between two arbitrary points.
> Think of it as a scatter-gather list with a wait-queue. That's what a pipe
> _is_. Trying to get rid of the pipe totally misses the whole point of
> splice()...
>
> ...it's what allows you to do _other_ things with splice that are simply
> impossible to do with sendfile. Notably, splice allows very naturally the
> "readv/writev" scatter-gather behaviour of _mixing_ streams. If you're a
> web-server, with splice you can do
>
>	    write(pipefd, header, header_len);
>	    splice(file, pipefd, file_len);
>	    splice(pipefd, socket, total_len);

The `splice()` lets us move data between, say, a file and a socket, for example
in an HTTP server, without that data ever being moved back and forth between our
user space program and the kernel. The kernel handles the moving of data
directly, and in some cases without any copying at all - which means less CPU
time, less memory usage and less memory allocations.

In addition, the use of a pipe also takes care of back pressure. I'll let Linus
explain:

> The reason you want to have a pipe in the middle is that you have to handle
> partial moves _some_ way. And the pipe being the buffer really does allow
> that, and also handles the case of "what happens when we received more data
> than we could write"...
>
> In particular, what happens when you try to connect two streaming devices, but
> the destination stops accepting data? You cannot put the received data "back"
> into the streaming source any way - so if you actually want to be able to
> handle error recovery, you _have_ to get access to the source buffers.

So, to sum up, if we want to directly move data between two arbitrary fd's, we
need to:

1. Create a pipe, with a read fd and a write fd, which actually encapsulates a
   kernel buffer.
2. Use `splice()` to move data from the source fd to the pipe.
3. Use `splice()` to move data from the pipe to the target fd.

Operations 2 and 3 would repeat until the source fd reaches end-of-file (EOF),
and ideally would run concurrently. Let's examine how we can do that using
Polyphony.

Polyphony introduces the `IO.splice` method, which has the following signature:

```ruby
IO.splice(src, dest, len)
```

This method splices a total of `len` bytes from `src` to `dest`, which are both
IO instances. If `len` is negative, `IO.splice` will keep splicing (with chunks
of up to `-len` bytes) until EOF is encountered. What's important to note about
this method is that it *will* block the current fiber if the source is not
readable or the destination is not writable. And of course, as stated above, at
least one of the IOs involved needs to refer to a pipe.

```ruby
def move_data_between_ios(source, target)
  r, w = IO.pipe
  f1 = spin do
    IO.splice(source, w, -8192)
    w.close
  end
  f2 = spin do
    IO.splice(r, target, -8192)
  end
  Fiber.await(f1, f2)
end
```

The `move_data_between_ios` method above starts by creating a pipe, then spins
up a fiber (`f1`) which splices data continuously from the source IO to the pipe
(until EOF is encountered), then closes the write end of the pipe. A second
fiber (`f2`) splices data from the pipe to the target IO, until the pipe has
reached EOF (hence the importance of the call to `w.close` in the first fiber).

So actually, there's a quite lot happening here: we split the work between two
fibers: one for moving data from the source to the pipe, another for moving data
from the pipe to the target. What's interesting is that these two concurrent
`splice` operations are dependent on the speed of both the source and the
target, with the pipe providing a buffer (by default holding [up to
64KB](https://unix.stackexchange.com/questions/11946/how-big-is-the-pipe-buffer)
of data) that can somewhat dampen any "stuttering" of either the source or the
target.

Finally, the performance of this double splice operation will be limited by the
slowest of the two. In other words, the above solution theoretically provides
the best possible behaviour in terms of responding to back pressure. Under ideal
conditions, where data is always available for reading from the source, and the
target always accepts more data to write, we pay a negligible price for passing
data first from the source to a kernel buffer, then from the buffer to the
target (the kernel performs splicing by incrementing reference counts, in
general [there's no copying of data
involved](https://man7.org/linux/man-pages/man2/splice.2.html#NOTES)). But when
we have a read-constrained source, or a write-constrained target, our kernel
buffer will allow us to minimize the time wasted waiting for data to become
readable or writable.

And the best part: we don't need to manage a user-space buffer in our program!
We could be streaming GBs of data without worrying about allocating Ruby strings
and stressing the Ruby GC. *And* we didn't need to copy data from the kernel to
our program and back.

You will have noticed, however, that there are some drawbacks to this approach:
we need to create a pipe, and we also need to create two fibers in which to run
the two `splice` operations concurrently. This overhead means that this approach
to moving data between two file descriptors is probably worth it only under
certain circumstances, for example above a certain quantity of data, but most
importantly when dealing with potentially slow clients, or when latency varies
wildly. Later on in this article I'll discuss some new APIs I have introduced
meant to reduce the overhead involved in performing concurrent splicing.

## Some use cases for splicing

Let's now look at a few examples that show how `splice()` can be used in a
variety of situations. The most obvious place to start is, for me, an echo
server. Since the echo server just sends back whatever you send to it, it seems
logical to use `splice` to implement it. Let's look at how a "normal" echo
server will be implemented using Polyphony:

```ruby
require 'polyphony'

def handle_client(conn)
  spin do
    while (data = conn.read(8192))
      conn.write(data)
    end
  end
end

server = TCPServer.open('127.0.0.1', 1234)
puts 'Echoing on port 1234...'
while (conn = server.accept)
  handle_client(conn)
end
```

As you can see, the `#handle_client` method simply reads from the client, then
writes the data back to the client. So the data itself does not interest us, we
don't do any processing on it, but we still need to create a string every time
we read from the connection, then write this string back.

## Echo server using splice

Using `splice`, however, frees us from having to deal with allocating Ruby
strings:

```ruby
def handle_client(conn)
  spin do
    r, w = IO.pipe
    spin do
      IO.splice(conn, w, -8192)
      w.close
    end
    IO.splice(r, conn, -8192)
  end
end
```

This version of `#handle_client` using `splice` looks almost identical to the
`move_data_between_ios` method discussed above. The only difference is that we
slightly reduce the overhead involved in setting up the concurrent operations by
spinning up only one fiber in addition to the fiber dedicated to the client. We
pass `-8192` as the `len` argument to `IO.splice`, which means that the splice
operation will be repeated until EOF is encountered, in chunks of 8KB.

## TCP proxy

Another use case for `splice` that comes to mind is a TCP proxy. Our TCP proxy
will accept incoming connections, will create a connection to some destination
TCP server, and will pass data in both directions between the two connections.

Here we need to setup two pipes and additional fibers in order to perform the
splicing in both directions:

```ruby
require 'polyphony'

DESTINATION = ['127.0.0.1', 1234]

def handle_client(conn)
  spin do
    dest = TCPSocket.new(*DESTINATION)

    r1, w1 = IO.pipe
    spin { IO.splice(conn, w1, -8192); w1.close }
    spin { IO.splice(r1, dest, -8192) }

    r2, w2 = IO.pipe
    spin { IO.splice(dest, w2, -8192); w2.close }
    IO.splice(r2, conn, -8192)
  rescue Errno::ECONNRESET
    # ignore
  ensure
    dest.close rescue nil
  end
end

puts "Serving TCP proxy on port 4321..."
TCPServer.new('127.0.0.1', 4321).accept_loop { |c| handle_client(c) }
```

For each incoming connection to our TCP proxy (serving on port 4321), a new
connection to the target (on port 1234) will be established, and then data will
be moved in both directions. Any data sent by the client will be spliced to the
destination connection, and any data received from the destination will be
spliced back to the client.

Note how we now need to create two pipes, one for each direction, and we need to
run four splice operations at once. As you can see, the overhead involved is
already substantial - we need to setup at least three more fibers to run our
splice operations, and we need to create two pipes with two IO instances for
each pipe. Surely we can do better...

## A better pipe abstraction

Let's start with pipes. Currently the Ruby core IO API provides the `IO.pipe`
method, which returns two IO instances - one for the read end of the pipe, and
one for the write end of the pipe. This way of working with pipes has two
problems: first, as discussed above, whenever we create a pipe we actually need
to allocate and setup two IO instances; and second, we need to name those IO
instances in a way that will signify their usage. Note how in the above TCP
proxy program I just gave generic names to the pipe ends:

```ruby
r1, w1 = IO.pipe
r2, w2 = IO.pipe
```

Those names are not very descriptive and it's easy to get them mixed up when
passing them to `IO.splice`. What if we introduced a `Pipe` class that
encapsulated both ends of the pipe? We can then give each pipe a name that will
mean something:

```ruby
client_to_dest_pipe = Polyphony.pipe
dest_to_client_pipe = Polyphony.pipe
```

The `Polyphony.pipe` method, introduced to Polyphony a few days ago does just
that. It offers the same API as a normal IO object, but any read operation will
be performed on the read end of the pipe, and any write operation will be
performed on the write end. This means that `Polyphony::Pipe` instances can be
used just like normal `IO` instances, and can also be passed to `IO.splice`.

So if we were to use `Polyphony.pipe` instead of `IO.pipe`, here's how the
`handle_client` method would look like:

```ruby
def handle_client(conn)
  spin do
    pipe = Polyphony.pipe
    spin do
      IO.splice(conn, pipe, -8192)
      pipe.close
    end
    IO.splice(pipe, conn, -8192)
  end
end
```

The difference is subtle, but notice how this code looks a lot cleaner, and we
have only a single variable acting as our pipe. We have saved on object
allocations, and we have also made our code more readable and easier to
understand. The TCP proxy example now looks like this:

```ruby
def handle_client(conn)
  spin do
    dest = TCPSocket.new(*DESTINATION)

    client_to_dest = Polyphony.pipe
    spin { IO.splice(conn, client_to_dest, -8192); client_to_dest.close }
    spin { IO.splice(client_to_dest, dest, -8192) }

    dest_to_client = Polyphony.pipe
    spin { IO.splice(dest, dest_to_client, -8192); dest_to_client.close }
    IO.splice(dest_to_client, conn, -8192)
  rescue Errno::ECONNRESET
    # ignore
  ensure
    dest.close rescue nil
  end
end
```

## Reducing fiber usage for splicing

The second issue we had, where we needed two splice operations to happen at the
same time, was that this necessitates two separate fibers to be running
concurrently. This is due to Polyphony's design, where each fiber can only
perform *one* blocking operation at a time.

But since the Polyphony backend is perfectly capable of launching multiple I/O
operations at once, it occurred to me that an abstraction that sets up a pipe,
then performs two concurrent `splice` operations could be immensely handy!
Here's the basic idea I came up with, implemented on the io_uring backend (the
actual implementation is
[here](https://github.com/digital-fabric/polyphony/blob/934be8ee42b0e816db1f4daa9f12c7e1fed5a816/ext/polyphony/backend_io_uring.c#L1009-L1069)):

```ruby
def backend_double_splice_to_eof(src, dest)
  r, w = create_pipe
  total = 0

  ctx_src = prep_splice_op_ctx(src, w)
  ctx_dest = prep_splice_op_ctx(r, dest)
  submit_deferred_sqes

  while true
    resume_value = backend_await
    if interrupted(resume_value)
      raise_if_error(resume_value)
      return value
    end

    if ctx_src&.completed?
      ctx_src.release
      if ctx_src.result == 0
        w.close
        ctx_src = nil
      else
        ctx_src = prep_splice_op_ctx(src, w)
      end
    end

    if ctx_dest&.completed?
      ctx_dest.release
      break if ctx_dest.result == 0

      total += ctx_dest.result
      ctx_dest = prep_splice_op_ctx(r, dest)
    end
    submit_deferred_sqes
  end

  total
ensure
  r.close
  w.close
end
```

Let's examine what's going on above.

- We start by creating a pipe and resetting a variable for counting the total
  bytes transferred.
- We then setup two operation contexts, one for each `splice` (source to pipe,
  pipe to destination), and submit the corresponding
  [SQEs](https://unixism.net/loti/ref-liburing/submission.html).
- We then start a loop:
  - We yield control to the next runnable fiber by calling backend_await. Our
    fiber will be resumed once any of the two `splice` operations completes.
  - We perform checks to see if the operation has been interrupted. If so, we
    either raise an error in case the resume value is an exception, or simply
    return the value.
  - We check if the `splice` moving data from the source to the pipe has
    completed.
    - If the result of the operation is 0, that means we have hit EOF and we can
      stop splicing from the source, and we can close the write-end of the pipe
      (in order to signal an EOF to the other `splice` operation.)
    - Otherwise, we create a new, identical `splice` operation in order to
      continue moving data from the source to the pipe.
  - We check if the `splice` moving data from the pipe to the destination has
    completed.
    - If the result of the operation is 0, that means we have hit EOF and we can
      break out of the loop.
    - Otherwise, we add the bytes transferred to our total bytes counter, and
      then create a new, identical `splice` operation to continue moving data
      from the pipe to the destination.
- We return the total bytes spliced, and make sure the pipe is closed.

So now that we have our `IO.double_splice_to_eof` method, let's see how our echo
server now looks:

```ruby
def handle_client(conn)
  spin do
    IO.double_splice(conn, conn, -8192)
  end
end
```

We have basically eliminated all of the code dealing with setting up a pipe and
performing two splices concurrently. And we still keep the same cancellation
behaviour (with Polyphony we can cancel any blocking operation at any moment).

Let's now see how this new method can be used in the TCP proxy we looked at
above:

```ruby
def handle_client(conn)
  spin do
    dest = TCPSocket.new(*DESTINATION)

    spin { IO.double_splice(conn, dest, -8192) }
    IO.double_splice(dest, conn, -8192)
  rescue Errno::ECONNRESET
    # ignore
  ensure
    conn.close rescue nil
    dest.close rescue nil
  end
end
```

Here we still need to spin up a second fiber so we could move data in both
directions at the same time, but we have greatly simplified our code, and
minimized the overhead involved. Here again, the actual data transferred between
the two sockets stays in the kernel, we just tell the kernel how to move it.

If we run both our TCP proxy and our echo server, we can easily test that they
both work correctly. Let's start by checking the echo server:

```bash
$ ruby examples/pipes/echo_server.rb &
$ echo "foobar" | nc -N localhost 1234
foobar
```

We can then run our TCP proxy, which will connect to our echo server:

```bash
$ ruby examples/pipes/tcp_proxy.rb &
$ echo "foobar" | nc -N localhost 4321
foobar
```

## Pipes and compression

Let's take a short detour from `splice` and look at some other new APIs recently
introduced in Polyphony, all related to data compression. The Ruby stdlib
includes the `zlib` gem, which provides a Ruby binding for `zlib` - a popular
library for compressing and decompressing data, and it works just fine, but I
wanted to create an API that will allow developers to compress data directly
between two file descriptors, without having to copy it to and from Ruby
strings.

The new compression/decompression APIs are:

- `IO.deflate(src, dest)`
- `IO.inflate(src, dest)`
- `IO.gzip(src, dest, info = nil)`
- `IO.gunzip(src, dest, info = nil)`

These four methods all take a source and a destination, which would normally be
IO instances, but they also accept Ruby strings as either a source or a
destination. `IO.gzip` takes an optional hash that can be used to set gzip meta
data, with the following keys:

- `:orig_name` - original file name
- `:mtime` - the file's time stamp
- `:comment` - comment

`IO.gunzip` can also take an optional hash that will be populated with the same
gzip meta data read from the source file descriptor, with the same keys as
`IO.gzip`. Here's a simple Ruby script that takes uncompressed data on `STDIN`,
gzips it and outputs the compressed data to `STDOUT`:

```ruby
require 'polyphony'

IO.gzip(STDIN, STDOUT)
```

We can very easily test that our script works correctly:

```bash
$ echo "foobar" | ruby gzip.rb | gunzip
foobar
```

The new compression/decompression APIs introduced in Polyphony have been
designed to minimize allocations when compressing or decompressing data between
two file descriptors (or IO instances.) To achieve this, the new
compression/decompression methods use static stack-allocated buffers. In
addition, the compression/decompression methods are tightly integrated with the
different backend I/O methods, so no Ruby strings are involved (Polyphony's
backend APIs such as `read`, `recv` etc. can read and write data directly
to/from raw buffers.)

## Splicing and compression

Now, you might be already guessing at what I aim to explore here: can we combine
pipes and those new compression APIs in order to create interesting I/O
pipelines that minimize both allocations and copying of data?

Suppose we want to be able to send compressed data using some protocol not
unlike HTTP/1.1 with [chunked transfer
encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding). What we need
to be able to do is to write a header with the (hexadecimal) chunk length
followed by `\r\n`, then splice the data, again followed by `\r\n` until we
finally signal EOF by writing `0\r\n\r\n` (an empty chunk) to the client. How
can we integrate data compression into this workflow?

The answer is: Just introduce more pipes. Let's look at the simplest case of
doing chunked transfer using `splice`, without any compression:

```ruby
MAX_CHUNK = 1 << 16

# src is the data source as an IO instance
# dest is the client's socket (or maybe an intermediary pipe)
def chunked_transfer(src, dest)
  pipe = Polyphony.pipe
  while true
    len = IO.splice(src, pipe, MAX_CHUNK)
    break if len == 0

    dest << "#{len}\r\n"
    IO.splice(pipe, dest, len)
    dest << "\r\n"
  end
  dest << "0\r\n\r\n"
end
```

The following diagram shows how the pipeline we created in `#chunked_transfer`:

```
+------+    +----+    +-----------+
|source| => |pipe| => |destination|
+------+    +----+    +-----------+
```

In essence, what `splice` allows us to do is to read a chunk of data from the
source into a kernel buffer (the pipe), then use the result (the number of bytes
read) to write a header to the destination, followed by a second `splice`
operation moving data from the kernel buffer to the destination. So we get to
control the moving of data between source and desination, without having to copy
data back and forth between the kernel and our program.

Using the above method is simple:

```ruby
def respond_from_io(conn, headers, io)
  conn << format_headers(headers)
  chunked_transfer(io, conn)
end

def respond_with_static_file(conn, req, headers = {})
  path = req.path
  if File.file?(path)
    File.open(path, 'r') { |f| respond_from_io(conn, headers, f) }
  end
end
```

Now if we also want to gzip the data before passing it to the client (which
browsers and users love!) we need to introduce an intermediary pipe in
conjunction with `IO.gzip`:

```ruby
def respond_from_io_gzipped(conn, headers, io)
  gzipped = Polyphony.pipe
  spin { IO.gzip(io, gzipped); gzipped.close }
  respond_from_io(conn, headers, gzipped)
end
```

In the above method, we create an additional `gzipped` pipe, and spin up a
separate fiber that will and zip all data from the given `io` to the `gzipped`
pipe. We then call `#respond_from_io`, which will perform the chunked transfer
from the `gzipped` pipe.

Here's a diagram representing how data moves in the above pipeline:

```
         fiber 1              fiber 2
            +               +---------+
            |               |         |
+------+    v    +-------+  v +----+  v +-----------+
|source| (gzip)> |gzipped| => |pipe| => |destination|
+------+         +-------+    +----+    +-----------+
```

As you can see, with a pipe, an extra fiber, and a call to `IO.gzip` we added a
substantial new feature to our fledgling pseudo-HTTP server, without having to
change our internal interfaces.

So, we see a pattern begin to emerge here: we have different methods that take a
source file descriptor (or IO instance) and a destination file descriptor, and
we create a pipeline by running them concurrently on separate fibers. Back
pressure is handled automatically (by virtue of using pipes as buffers), and we
reduce CPU and memory usage to the strict minimum, all while still writing Ruby!

## Performance

I don't mean to disappoint you, but I still don't have any numbers to show you
regarding performance. In the last month I've been juggling work, gardening and
family affairs, and I didn't have enough time to do benchmarks. I'll try to that
in the comings weeks and publish the results in a subsequent article. Currently
all I have is my intuition, which tells me there's a lot to be gained from using
the new APIs and ideas I've exposed in this article. If my intuition proves
right, they will make their way to
[Tipi](https://github.com/digital-fabric/tipi), the web server which I've been
working on for a while now.

## Future directions

A few weeks ago [I wrote](/articles/2022-03-05-february-summary) about some
future directions I've been looking at, including a new gem for writing HTTP/2
clients and servers, as well as a new HTTP client library. I hope to be able to
make some progress on these as well in the coming month (or two.) [Let me
know](/about) if you have any question about any of this stuff. If you care
about my work, please consider [becoming a sponsor on
Github](https://github.com/sponsors/ciconia).
