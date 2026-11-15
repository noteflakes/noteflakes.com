---
title: "OSS Friday Update - The Fiber Scheduler is Taking Shape"
layout: article
---

This week I made substantial progress on the
[UringMachine](https://github.com/digital-fabric/uringmachine) fiber scheduler
implementation, and also learned quite a bit about the inner workings of the
Ruby I/O layer. Following is my weekly report:

- I added some benchmarks measuring how the UringMachine mutex performs against
  the stock Ruby Mutex class. It turns out the `UM#synchronize` was much slower
  than core Ruby `Mutex#synchronize`. This was because the UM version was always
  performing a futex wake before returning, even if no fiber was waiting to lock
  the mutex. I rectified this by adding a `num_waiters` field to `struct
  um_mutex`, which indicates the number of fibers currently waiting to lock the
  mutex, and avoiding calling `um_futex_wake` if it's 0.

- I also noticed that the `UM::Mutex` and `UM::Queue` classes were marked as
  `RUBY_TYPED_EMBEDDABLE`, which means the underlying `struct um_mutex` and
  `struct um_queue` were subject to moving. Obviously, you cannot just move a
  futex var while the kernel is potentially waiting on it to change. I fixed
  this by removing the `RUBY_TYPED_EMBEDDABLE` flag.

- Added support for `IO::Buffer` in all low-level I/O APIs, which also means
  the fiber scheduler doesn't need to convert from `IO::Buffer` to strings in
  order to invoke the UringMachine API.

- Added a custom `UM::Error` exception class raised on bad arguments or other
  API misuse. I've also added a `UM::Stream::RESPError` exception class to be
  instantiated on RESP errors. (commit 72a597d9f47d36b42977efa0f6ceb2e73a072bdf)

- I explored the fiber scheduler behaviour after forking. A fork done from a
  thread where a scheduler was set will result in a main thread with the same
  scheduler instantance. For the scheduler to work correctly after a fork, its
  state must be reset. This is because sharing the same io_uring instance
  between parent and child processes is not possible
  (https://github.com/axboe/liburing/issues/612), and also because the child
  process keeps only the fiber from which the fork was made as its main fiber
  (the other fibers are lost).

- On Samuel's suggestions, I've submitted a
  [PR](https://github.com/ruby/ruby/pull/15342) for adding a
  `Fiber::Scheduler#process_fork` hook that is automatically invoked after a
  fork. This is in continuation to the `#post_fork` method. I still have a lot
  to learn about working with the Ruby core code, but I'm really excited about
  the possibility of this PR (and the [previous
  one](https://github.com/ruby/ruby/pull/15213) as well) getting merged in time
  for the Ruby 4.0 release.

- Added two new low-level APIs for waiting on processes, instead of
  `UM#waitpid`, using the io_uring version of `waitid`. The vanilla version
  `UM#waitid` returns an array containing the terminated process pid, exit
  status and code. The `UM#waitid_status` method returns a `Process::Status`
  with the pid and exit status. This method is present only if the
  `rb_process_status_new` function is available (see above).

- Implemented `FiberScheduler#process_wait` hook using `#waitid_status`.

- For the sake of completeness, I also added `UM.pidfd_open` and
  `UM.pidfd_send_signal` for working with PID. A simple example:

  ```ruby
  child_pid = fork { ... }
  fd = UM.pidfd_open(child_pid)
  ...
  UM.pidfd_send_signal(fd, UM::SIGUSR1)
  ...
  pid2, status = machine.waitid(P_PIDFD, fd, UM::WEXITED)
  ```

- Wrote a whole bunch of tests for `UM::FiberScheduler`: socket I/O, file I/O,
  mutex, queue, waiting for threads. In the process I discovered a lots of
  things that can be improved in the way Ruby invokes the fiber scheduler.

## Things I Learned This Week

As I dive deeper into integrating UringMachine with the `Fiber::Scheduler`
interface, I'm discovering all the little details about how Ruby does I/O. As I
wrote last week, Ruby treats files differently than other `IO` types, such as
sockets and pipes:

- For regular files, Ruby assumes file I/O can never be non-blocking (or async),
  and thus invokes the `#blocking_operation_wait` hook in order to perform the
  I/O in a separate thread. With io_uring, of course, file I/O *is*
  asynchronous.
- For sockets there are no specialized hooks, like `#socket_send` etc. Instead,
  Ruby makes the socket fd's non-blocking and invokes `#io_wait` to wait for the
  socket to be ready when performing a `send` or `recv`.
  
I find it interesting how io_uring breaks a lot of assumptions about how I/O
should be done. Basically, with io_uring you can treat *all* fd's as blocking
(i.e. without the `O_NONBLOCK` control flag), and you can use io_uring to
perform asynchrnous I/O on them, files included!

It remains to be seen if in the future the Ruby I/O implementation could be
simplified to take full advantage of io_uring. Right now, the way things are
done in the core Ruby IO classes leaves a lot of performance opportunities on
the table. So, while the UringMachine fiber scheduler implementation will help
in integrating UringMachine with the rest of the Ruby ecosystem, to really do
high-performance I/O, one would still need to use UringMachine's low-level API.

## What's Coming Next Week

Next week I hope to finish the fiber scheduler implementation by adding the last
few things that are missing: handling of timeout, the `#io_pread` and
`io_pwrite` hooks, and a few more minor features, as well as a lot more testing.

I also plan to start benchmarking UringMachine and compare the performance of
its low-level API, the UringMachine fiber scheduler, and the regular
thread-based concurrent I/O.

I also have some ideas for improvements to the UringMachine low-level
implementation, which hopefully I'll be able to report on next week.

If you appreciate my OSS work, please consider becoming a
[sponsor](https://github.com/sponsors/noteflakes).