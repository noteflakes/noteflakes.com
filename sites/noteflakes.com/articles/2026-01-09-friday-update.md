---
title: "Exploring automatic Buffer Management with io_uring"
layout: article
---

In the last few months I've been working on
[UringMachine](https://github.com/digital-fabric/uringmachine), a Ruby gem for
doing I/O with io_uring, and I've been reporting on my progress on my website,
as part of my grant work for the [Ruby Association](https://www.ruby.or.jp/en/).

## A Quick Recap

Since we're now in 2026 (happy new year everybody!), here's a quick recap of
what UringMachine does: UringMachine provides a low-level API for performing I/O
operations using io_uring, which is an interface for performing I/O operations
asynchronously on recent Linux kernels.

UringMachine also provides a [Fiber
Scheduler](https://docs.ruby-lang.org/en/master/Fiber/Scheduler.html)
implementation that allows it to integrate nicely with the rest of the Ruby
ecosystem and be used in any Ruby application that supports fiber concurrency.

In my work on this project I've been looking to find just the right level of
abstraction that on the one hand allows harnessing the full power of io_uring to
bring high-performance I/O to Ruby, and on the other hand provide a convenient
and practical Ruby API, and good integration with the entire Ruby ecosystem.

Here are some of the things I've been working on since starting the grant work:

- A full-featured `FiberScheduler` interface implementation.
- Some minor contributions to the `FiberScheduler` integration code in the Ruby
  runtime.
- Comprehensive tests.
- Support for `IO::Buffer` in the different I/O methods.
- Support for vectorized `writev`/`sendv`.
- Comprehensive metrics.
- Support for SQPOLL mode.
- Support for Sidecar mode.
- Lots of [benchmarking](/articles/2025-12-19-friday-update).

## Automatic Buffer Management

In the last week I've been working on implementing with automatic buffer
manangement. As is my custom, I've been thinking about the design for this
feature since the last few weeks already, and following the Christmas vacation I
decided the idea is solid enough for me to start writing some code. But let me
back up and explain what I'm trying to achieve here.

One of the more recent features of the io_uring interface is a facility for
setting up buffer rings. The idea is that the application provides buffers to
the kernel, which can then use those buffers for reading or receiving data
repeatedly from a given file or socket, letting the application know with each
CQE which buffer was used and with how much data.
  
The application initiates multishot read/recv operations on each connection, and
the kernel has at its disposition a pool of application-provided buffers that it
can use whenever a chunk of data is read / received. So the kernel consumes
those buffers as needed, and fills them with data ass it becomes available.
Those data will be processed by the application at some later time when it's
ready to process CQEs. Eventually, after processing the data, the application
will add the consumed buffers back to the buffer ring, making them available to
the kernel again.

Multiple buffer rings may be registered by the application, each with a set
maxmimum number of buffers and with a buffer group id (`bgid`). The buffers
added to a buffer ring may be of any size. Each buffer in a buffer ring also has
an id (`bid`). So buffers are identified by the tuple `[bgid, bid]`. When
submitting a multishot read/recv operation, we indicate the buffer group id
(`bgid`), letting the kernel know which buffer ring to use. The kernel then
generates CQEs (completion queue entries) which contain the id of the buffer
that contains the data (`bid`). Crucially, a single buffer ring may be used in
multiple concurrent multishot read/recv operations on different file
descriptors.

In addition,on recent kernels io_uring is capable of partially consuming
buffers, which prevents wasting of buffer space. When a buffer ring is set up
for [partial buffer
consumption](https://www.man7.org/linux/man-pages/man3/io_uring_setup_buf_ring.3.html),
each CQE relating to a multishot read/recv operation will also have a flag
telling the application know [whether the buffer will be further
used](https://www.man7.org/linux/man-pages/man3/io_uring_prep_recv.3.html)
beyond the amount of data readily available. Each read/recv completion with the
same buffer ID will continue where the previous one left off. This means that
buffer space is used fully, but the downside of this is that the application is
required to keep track of a "cursor" for each buffer.

So I wanted to design a sub-system that manages buffers automatically:
registering buffer groups, allocating and adding buffers to the individual
buffer rings, and keeping track of the usage of each buffer. But I also wanted
to come up with a good way to use these buffers from the point of view of the
application.

## How Applications Use Buffers

How do we normally use I/O buffers in Ruby applications? The stock `IO` class
conveniently includes buffering functionality for both reading and writing from
a file/socket. These makes it possible to implement APIs like `IO#gets`.

Depending on the protocol, we might need to read data line by line, or a single
byte, or maybe a string with an arbitrary length, or a combination of those. So,
an application that wants to parse, say, an HTTP/1.1 request, will need first to
read the request headers, each of which is terminated by a `\r\n` separator, and
then read the request body, which has an arbitrary length, according to the
given headers. This makes it necessary to read data into a buffer, which might
need to be resized and/or truncated as more data is read.

