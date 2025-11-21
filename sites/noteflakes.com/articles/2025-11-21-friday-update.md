---
title: "OSS Friday Update"
layout: article
---

Note: while my schedule is quite hectic these last few weeks, I've taken the
decision to dedicate at least one day per week for developing open-source tools,
and henceforth I plan to post an update on my progress in this regard every
Friday evening. Here's the first update:

## UringMachine Grant Work

As I wrote here previously, a few weeks ago I learned I've been selected as one
of the recipients of a [grant](https://www.ruby.or.jp/en/news/20251030) from the
Ruby Association in Japan, for working on UringMachine, a new gem that brings
low-level io_uring I/O to Ruby. For this project, I've been paired with a
terrific mentor - [Samuel Williams](https://github.com/ioquatix/) - who is *the*
authority on all things related to Ruby fibers. We've had a talk about the
project and discussed the different things that I'll be able to work on. I'm
really glad to be doing this project under his guidance.

UringMachine implements a quite low-level API for working with I/O. You
basically work with raw file descriptors, you can spin up fibers for doing
multiple things concurrently, and there are low-level classes for mutexes and
queues (based on the io_uring implementation of the
[futex](https://www.man7.org/linux/man-pages/man2/futex.2.html) API).
Incidentally, I find it really cool that futexes can be used with io_uring to
synchronize fibers, with very low overhead.

The problem with this, of course, is that this API is useless when you want to
use the standard Ruby I/O classes, or any third-party library that relies on
those standard classes.

This is where the Ruby fiber scheduler comes into the picture. Early on in my
work on UringMachine, it occurred to me that the `Fiber::Scheduler` added to
Ruby by Samuel is a perfect way to integrate such a low-level API with the Ruby
I/O layer and the entire Ruby ecosystem. An implementation of `Fiber::Scheduler`
for UringMachine would use the different scheduler hooks to punt work to the
low-level UringMachine API.

So this week I finally got around to making some progress on the UringMachine
fiber scheduler, and there's finally a basic working version that can do basic
I/O, as well as some other stuff like sleeping, waiting on blocking operations
(such as locking a mutex or waiting on a queue), and otherwise managing the life
cycle of a scheduler.

This is also a learning process. The Ruby `IO` class implementation is really
complex: the [`io.c`](https://github.com/ruby/ruby/blob/master/io.c) file itself
is about 10K LOCs! I'm still figuring out the mechanics of the fiber scheduler
as I go, and lots of things are still unclear, but I'm taking it one step at a
time, and when I hit a snag I just try to take the problem apart and try to
understand what's going on. But now that I have moved from a rough sketch to
something that works and has some tests, I intend to continue working on it by
adding more and more tests and TDD'ing my wait to an implementation that is both
complete (feature-wise) and robust.

Here are some of the things I've learned while working on the fiber scheduler:

- When you call `Kernel.puts`, the trailing newline character is actually
  written separately, which can lead to unexpected output if for example you
  have multiple fibers writing to STDOUT at the same time. To prevent this, Ruby
  uses a mutex (per IO instance) to synchronize writes to the same IO.

- There are inconsistencies in how different kinds of IO objects are handled,
  with regards to blocking/non-blocking operation
  ([O_NONBLOCK](https://linux.die.net/man/2/fcntl)):

  - Files and standard I/O are blocking.
  - Pipes are non-blocking.
  - Sockets are non-blocking.
  - OpenSSL sockets are non-blocking.

  The problem is that for io_uring to function properly, the fds passed to it
  should always be in blocking mode. To rectify this, I've added code to the
  fiber scheduler implementation that makes sure the IO instance is blocking:

  ```ruby
  def io_write(io, buffer, length, offset)
    reset_nonblock(io)
    @machine.write(io.fileno, buffer.get_string)
  rescue Errno::EINTR
    retry
  end

  def reset_nonblock(io)
    return if @ios.key?(io)
        
    @ios[io] = true
    UM.io_set_nonblock(io, false)  
  end
  ```

- A phenomenon I've observed is that in some situations of multiple fibers doing
  I/O, some of those I/O operations would raise an `EINTR`, which should mean
  the I/O operation was interrupted because of a signal sent to the process.
  Weird!

- There's some interesting stuff going on when calling `IO#close`. Apparently
  there's a mutex involved, and I noticed two scheduler hooks are being called:
  `#blocking_operation_wait` which means a blocking operation that should be ran
  on a separate thread, and `#block`, which means a mutex is being locked. I
  still need to figure out what is going on there and why it is so complex.
  FWIW, UringMachine has a `#close_async` method which, as its name suggests,
  submits a close operation, but does not wait for it to complete.

## Improving and extending the fiber scheduler interface

One of the things I've discussed with Samuel is the possibility of extending the
fiber scheduler interface by adding more hooks, for example a hook for closing
an IO (from what I saw there's already some preparation for that in the Ruby
runtime), or a hook for doing a `splice`. We've also discussed working with
`pidfd_open` to prevent race conditions when waiting on child processes. I think
there's still a lot of cool stuff that can be done by bringing low-level I/O
functionality to Ruby.

I've also suggested to Samuel to use the relatively recent
`io_uring_prep_waitid` API to wait for child processes, and more specifically to
do this in Samuel's own [io-event](https://github.com/socketry/io-event/) gem,
which provides a low-level cross-platform API For building async programs in
Ruby. With the io_uring version of `waitid`, there's no need to use `pidfd_open`
(in order to poll for readiness when the relevant process terminates). Instead,
we use the io_uring interface to directly wait for the process to terminate.
Upon termination, the operation completes and we get back the pid and status of
the terminated process. This is also has the added advantage that you can wait
for any child process, or any child process in the process group, which means
better compatibility with the `Process.wait` and associated methods.

One problem is that the fiber scheduler `process_wait` hook is supposed to
return an instance of `Process::Status`. This is a core Ruby class, but you
cannot create instances of it. So, if we use io_uring to directly wait for a
child process to terminate, we also need a way to instantiate a
`Process::Status` object with the information we get back from io_uring. I've
submitted a [PR](https://github.com/ruby/ruby/pull/15213) that hopefully will be
merged before the release of Ruby 4.0. I've also submitted a
[PR](https://github.com/socketry/io-event/pull/154) to io-event with the
relevant changes.

## Going forward

So here's where the UringMachine project is currently at:

- The fiber scheduler [implementation](https://github.com/digital-fabric/uringmachine/blob/main/lib/uringmachine/fiber_scheduler.rb).
- The fiber scheduler [tests](https://github.com/digital-fabric/uringmachine/blob/main/test/test_fiber_scheduler.rb).
- My grant [development journal](https://github.com/digital-fabric/uringmachine/blob/main/grant-2025/journal.md).

If you appreciate my OSS work, please consider [sponsoring
me](https://github.com/sponsors/noteflakes).

## My Consulting Work

Apart from my open-source work, I'm also doing consulting work for. Here's some
of the things I'm currently working on for my clients:

- Transitioning a substantial PostgreSQL database (~4.5TB of data) from RDS to
  EC2. This is done strictly for the sake of reducing costs. My client should
  see a reduction of about 1000USD/month.
- Provisioning of a new web platform for industrial process control for a client
  in India.
- Exploring the integration of AI tools for analyzing the performance of
  equipment such as water pumps for water treatment facilities. I'm still quite
  sceptical about LLM's being the right approach for this. ML algorithms might
  be a better fit. Maybe, we'll see...

