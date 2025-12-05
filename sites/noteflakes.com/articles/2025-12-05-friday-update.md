---
title: "OSS Friday Update - The Shape of Ruby I/O to Come"
layout: article
---

I'm currently doing grant work for the Japanese Ruby Association on
[UringMachine](https://github.com/digital-fabric/uringmachine), a new Ruby gem
that provides a low-level API for working with
[io_uring](https://unixism.net/loti/what_is_io_uring.html). As part of my work
I'll be providing weekly updates on this website. Here's what I did this week:

- Last week I wrote about the work I did under the guidance of [Samuel
  Williams](https://github.com/ioquatix) to improve the behavior of fiber
  schedulers when forking. After some discussing the issues around forking with
  Samuel, we decided that the best course of action would be to remove the fiber
  scheduler after a fork. Samuel did work around [cleaning up schedulers in
  threads that terminate on fork](https://github.com/ruby/ruby/pull/15354), and
  I submitted a [PR](https://github.com/ruby/ruby/pull/15385) for removing the
  scheduler from the active thread on fork, as well as resetting the fiber to
  blocking mode. This is my first contribution to Ruby core!

- I Continued implementing the missing fiber scheduler hooks:
  `#fiber_interrupt`, `#address_resolve`, `#timeout_after`. For the most part,
  they were simple to implement. I probably spent most of my time figuring out
  how to test these, rather than implementing them. Most of the hooks involve
  just a few lines of code, with many of them consisting of a single line of
  code, calling into the relevant UringMachine low-level API.

- Implemented the `#io_select` hook, which involved implementing a low-level
  `UM#select` method. This method took some effort to implement, since it needs
  to handle an arbitrary number of file descriptors to check for readiness. We
  need to create a separate SQE for each fd we want to poll. When one or more
  CQEs arrive for polled fd's, we also need to cancel all poll operations that
  have not completed.

  Since in many cases, `IO.select` is called with just a single IO, I also added
  a special-case implementation of `UM#select` that specifically handles a
  single fd.

- Implemented a worker pool for performing blocking operations in the scheduler.
  Up until now, each scheduler started their own worker thread for performing
  blocking operations for use in the `#blocking_operation_wait` hook. The new
  implementation uses a worker thread pool shared by all schedulers, with a
  worker count limited to CPU count. Workers are started when needed.

  I also added an optional `entries` argument to set the SQE and CQE buffer
  sizes when starting a new `UringMachine` instance. The default size is 4096
  SQE entries (liburing by default makes the CQE buffer size double that of the
  SQE buffer). The blocking operations worker threads specify a value of 4 since
  they only use their UringMachine instance for popping jobs off the job queue
  and pushing the blocking operation result back to the scheduler.

- Added support for `file_offset` argument in `UM#read` and `UM#write` in
  preparation for implementing the `#io_pread` and `#io_pwrite` hooks. The
  `UM#write_async` API, which permits writing to a file descriptor without
  waiting for the operation to complete, got support for specifying `length` and
  `file_offset` arguments as well. In addition, `UM#write` and `UM#write_async`
  got short-circuit logic for writes with a length of 0.

- Added support for specifying buffer offset in `#io_read` and `#io_write`
  hooks, and support for timeout in `#block`, `#io_read` and `#io_write` hooks.

- I found and fixed a problem with how `futex_wake` was done in the low-level
  UringMachine code handling mutexes and queues. This fixed a deadlock in the
  scheduler background worker pool where clients of the pool where not properly
  woken after the submitted operation was done.

- I finished work on the `#io_pread` and `#io_pwrite` hooks. Unfortunately, the
  test for `#io_pwrite` consistently hangs (not in `IO#pwrite` itself, rather on
  closing the file.) With Samuel's help, hopefully we'll find a solution...

- With those two last hooks, the fiber scheduler implementation is now feature
  complete!

## Why is The Fiber Scheduler Important?

I think there is some misunderstanding around the Ruby fiber scheduler
interface. This is the only Ruby API that does not have a built-in
implementation in Ruby itself, but rather requires an external library or gem.
The question has been raised lately on Reddit, why doesn't Ruby include an
"official" implementation of the fiber scheduler?

I guess Samuel is really the person to ask this, but personally I would say this
is really about experimentation, and seeing how far we can take the idea of a
pluggable I/O implementation. Also, the open-ended design of this interface
means that we can use a low-level API such as UringMachine to implement it.

## What's Coming Next Week?

Now that the fiber scheduler is feature complete, I'm looking to make it as
robust as possible. For this, I intend to add a lot of tests. Right now, the
fiber scheduler has 25 tests with 77 assertions, in about 560LOC (the fiber
scheduler itself is at around 220LOC). To me this is not enough, so next week
I'm going to add tests for the following:

- IO - tests for all IO instance methods.
- working with queues: multiple concurrent readers / writers.
- `net/http` test: ad-hoc HTTP/1.1 server + `Net::HTTP` client.
- sockets: echo server + many clients.

In conjunction with all those tests, I'll also start working on benchmarks for
measuring the performance of the UringMachine low-level API against the
UringMachine fiber scheduler and against the "normal" thread-based Ruby APIs.

In addition, I'm working on a pull request for adding an `#io_close` hook to the
fiber scheduler interface in Ruby. Samuel already did some preparation for this,
so I hope I can finish this in time for it to be merged in time for the release
of Ruby 4.0.

I intend to release UringMachine 1.0 on Christmas, to mark the release of Ruby
4.0.

## What About Papercraft?

This week I also managed to take the time to reflect on what I want to do next
in [Papercraft](https://github.com/digital-fabric/papercraft). I already wrote
here about wanting to implement template inlining for Papercraft. I also wanted
to rework how the compiled code is generated. I imagined a kind of DSL for code
generation, but I didn't really know what such a DSL would look like.

Then, a few days ago, the idea hit me. I've already played with this idea a last
year, when I wrote Sirop, a sister gem to Papercraft that does a big part of the
work of converting code into AST's and vice versa. Here's what I put in the
readme:

> Future directions: implement a macro expander with support for quote/unquote:
>
> trace_macro = Sirop.macro do |ast|
>   source = Sirop.to_source(ast)
>   quote do
>     result = unquote(ast)
>     puts "The result of #{source} is: #{result}"
>     result
>   end
> end

> def add(x, y)
>   trace(x + y)
> end

> Sirop.expand_macros(method(:add), trace: trace_macro)

The example is trivial and contrived, but I suddenly understand how such an
interface could be used to actually generate code in Papercraft. I wrote up an
[issue](https://github.com/digital-fabric/sirop/issues/1) for this, and
hopefully I'll have some time to work on this in January.
