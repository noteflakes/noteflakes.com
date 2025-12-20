---
title: "Threads vs Fibers - Can't We Be Friends?"
layout: article
---

In the last few weeks I've been writing here about my work on
[UringMachine](https://github.com/digital-fabric/uringmachine), a Ruby gem for
doing I/O with io_uring. Before I talk about my work this week, I'd like to
address something that is important to me.

## Maybe, We'll See...

I usually share my blog posts in a few different places on the internet, and
sometime people write their reactions. Last week, on Reddit, someone didn't like
the title (of all things... 🙂) I gave my [last blog
post](/articles/2025-12-12-friday-update), and made the following remark:

> When a project or people aren't open on what their tech is good for, and what
> it's not good for, it really drives me away...

To which I replied:

> I try to be as open as possible, and the thing is I don't yet know what this
> is good for, but I'm excited about the possibilities.

To which that person retorted:

> I find it surprising one would get involved with such project without having
> an idea of the result to expect. The pros and cons of fibers and async are
> pretty well known.

Well, starting this project I did have some vague idea of what will happen if
we combined Ruby fibers with io_uring. At the same time, I wanted to be able to
show some concrete results (as in, benchmarks), and in that sense I don't think
anyone could claim they could know the expected result in advance.

But also, in a more general sense, I believe it would have been presumtuous,
even arrogant for me to claim I already knew everything there was to know about
io_uring, Ruby fibers and how the two would work together. Yes, there's a
general agreement that fibers are good for I/O-bound work and less useful for
CPU-bound work, but that is just a general concept.

Beyond that, there are a lot of questions to answer: Where are the limits? Can
an I/O-bound workload become CPU-bound, or vice versa? What about mixed
workloads? What are the shortcomings of the Fiber Scheduler interface? Are there
other things we can improve about Ruby's I/O layer? And finally, would this work
lead to new solutions for apps written in Ruby? I don't know the answer to these
questions, but that's what I want to find out!

In that regard, I really appreciate the remarks that Matz made at the last Euruko
conference in Viana do Castelo. He talked about the spirit of openess and
experimentation and inquisitiveness: is this project worth anything, or is it
just a *big waste of time*? Who knows? I guess we'll see...

## So, Back to UringMachine

This week I continued work on benchmarking UringMachine against other
concurrency solutions. I also spent more time testing the functioning of the
UringMachine fiber scheduler. I noticed that when using an `IO` with buffered
writes (which is the default in Ruby,) when the IO's write buffer is flushed,
the fiber scheduler's `#io_write` hook would not get invoked. Instead, Ruby
would invoke the `#blocking_operation_wait` hook, which run a blocking `write`
system call on a worker thread. This, of course, is far from being satisfactory,
as io_uring lets us run file I/O asynchronously. So I submitted a
[fix](https://github.com/ruby/ruby/pull/15609) which has been already been
merged into the Ruby 4.0 release.

Measuring how fast UringMachine goes led to some work on the UringMachine
low-level API implementation. For example, I added methods for doing vectorized
`write` and `send` (io_uring provides support for vectorized `send` as of kernel
version 6.17). So, `UM#writev` and `UM#sendv` let you write or send multiple
buffers at once. I still need to measure how those methods stack up against the
other ways of writing tro a socket, but from some experiments I did this does
seem promising.

## Between UringMachine and the Ruby GVL

While I was working on the UringMachine benchmarks, it occurred to me that the
UM implementation of I/O operations has one substantial shortcoming: while
UringMachine does a great job of switching between fibers that are runnable,
every once in a while it still has to enter the kernel in order to process
submission entries, and completion entries.

Let's back up a bit: the way UringMachine works is that when a fiber calls one
of the UringMachine I/O methods, UringMachine prepares a submission queue entry
(SQE), and switches execution to the next fiber in the runqueue. When the
runqueue is exhausted, UringMachine calls, depending on the context,
`io_uring_submit` or `io_uring_wait_for_cqe` in order to tell the kernel to
process pending entries in the submission queues, and also to wait for at least
one completion entry (CQE) to become available.

Those functions to interact with io_uring (from
[liburing](https://github.com/axboe/liburing/), which provides a nicer interface
to the io_uring kernel API), are actually wrappers to the `io_uring_enter`
system call, and therefore are potentially blocking. In order to play nice with
Ruby, UringMachine will release the Ruby GVL while this system call is in
progress, and will reacquire the Ruby GVL when the system call returns.

What this means is that with UringMachine, when there's no more CPU-bound work
to do, and all fibers are waiting on some I/O operation to complete,
UringMachine will "stop the world" and wait for one or more I/O operations to
complete. It follows then that in a single-thread setup, the GVL will be
periodically unused for a certain amount of time, depending on the I/O work
being done. Naturally, the exact amount of time the GVL is available will be
reduced as the I/O load increases, but it will still be there, and therefore the
GVL as a resource will never be 100% saturated.

So, if we ran multiple instances of UringMachine on separate threads, we might
be able to better saturate the GVL and thus achieve higher throughput for our
I/O workload. This, at least was my theory.

It should be noted that up until now, when discussing the different solutions
for concurrency in Ruby, we've been talking about *either* threads *or* fibers.
The basic approach says: you can *either* run your workload on multiple threads,
where you'll enjoy some parallelism when any thread does I/O work; *or* you can
run your workload on a single thread using multiple fibers, which lets you run a
very large number of concurrent I/O operations and amortize some of the cost of
talking to the kernel over multiple operations (preferably using io_uring).

But in fact those two approaches have important shortcomings: with threads
you're limited in terms of how many I/O operations you can do concurrently, and
you pay a heavy price on GVL contention (that is, you'll eventually see worse
performance as you increase the number of threads); with fibers, your CPU-bound
code is penalized because you need to periodically "stop the world" and talk to
the kernel in order to process your I/O.

But what would happen if we actually used multiple threads, and on each thread
we ran multiple fibers? What if it wasn't an either / or situation, but rather
threads *and* fibers?

## What's Faster than Fibers? Threads + Fibers!

So eager to test my theory, I rolled my sleeves and added some code to the
UringMachine benchmarks. I wanted to test how UringMachine performs when the
workload is split across 2 or more threads. Here's the code that drives the
implementation:

```ruby
def run_um_x2
  threads  = 2.times.map do
    Thread.new do
      machine = UM.new(4096)
      fibers = []
      fds = []
      do_um_x(2, machine, fibers, fds)
      machine.await_fibers(fibers)
      fds.each { machine.close(it) }
    end
  end
  threads.each(&:join)
end
```

And here's the `do_um_x` code for the `bm_io_pipe` benchmark:

```ruby
def do_um_x(div, machine, fibers, fds)
  (GROUPS/div).times do
    r, w = UM.pipe
    fibers << machine.spin do
      ITERATIONS.times { machine.write(w, DATA) }
      machine.close_async(w)
    end
    fibers << machine.spin do
      ITERATIONS.times { machine.read(r, +'', SIZE) }
      machine.close_async(r)
    end
  end
end
```
 
Basically, it does the same thing, but since it's invoked for each thread, we
divide the number of "groups" by the number of threads, so if we have say 2
threads and 48 groups in total, on each thread we'll start 24 of them. Here are
the results:

```
                    user     system      total        real
Threads         4.638775   5.723567  10.362342 (  9.306601)
Async uring     2.197082   1.101110   3.298192 (  3.298313)
Async uring x2  2.471700   1.186602   3.658302 (  3.654717)
UM FS           1.167294   0.668348   1.835642 (  1.835746)
UM FS x2        1.169006   0.726825   1.895831 (  1.208773)
UM              0.430376   0.666198   1.096574 (  1.096809)
UM x2           0.463280   0.708560   1.171840 (  0.622890)
UM x4           0.589586   0.995353   1.584939 (  0.795669)
UM x8           0.889519   1.210246   2.099765 (  1.251179)
```

If we just look at the pure UM implementations, we see the 2 threads version
providing a significant speedup over the single thread version (0.62s vs. 1.10s,
or ~1.77 times faster). But we also see that as we increase the thread count
we got dimishing returns, as the 4 thread version is slower than the 2 thread
version, and the 8 thread version is even slower than the single thread version.

Looking at the fiber scheduler implementations, we see the Async fiber scheduler
actually performing worse with 2 threads, and the UM fiber scheduler performing
somewhat better (1.21s vs. 1.84s, about 1.52 times faster).

Running the `bm_io_socketpair` benchmark will yield a somewhat different result:

```
                    user     system      total        real
Threads         3.107412   4.375018   7.482430 (  5.518199)
Async uring     1.168644   2.116141   3.284785 (  3.285159)
Async uring x2  2.115308   4.267043   6.382351 (  4.233598)
UM FS           1.002312   1.910953   2.913265 (  2.913601)
UM FS x2        2.077869   4.041456   6.119325 (  3.984509)
UM              0.319183   1.618411   1.937594 (  1.937892)
UM x2           0.367900   1.700580   2.068480 (  1.114170)
UM x4           0.431765   1.881608   2.313373 (  0.768043)
UM x8           0.497737   2.286719   2.784456 (  0.831759)
```

Here we see the UringMachine fiber scheduler also performing worse in a
multithreaded setup. This might be due to the fact that the fiber scheduler
interface does not have hooks for socket operations such as `send` and `recv`,
and it only participates in the actual I/O operations via its `io_wait` hook,
which is invoked to check for readiness before Ruby performs the actual socket
I/O.

Looking at the pure UringMachine implementation, we also see a performance
increase as we increase the number of threads, but eventually we'll see a
performance degradation as we go past 4 threads.

So, this technique of starting up multiple threads, each with its UringMachine
instance and multiple concurrent fibers, definitely has value, but the actual
performance increase we'll get, and the ideal number of threads we start,
is highly dependant on the actual workload.

I wanted to go a bit beyond those synthetic benchmarks and see how UM does under
a more realistic scenario - that of a web server. So I sketched a very simple
web server that listens for incoming connections, parses HTTP requests, and
sends response headers followed by a response body. I then measured how it did
using [rewrk](https://github.com/lnx-search/rewrk) with the following command:

```bash
$ rewrk -c 256 -t 4 -d 10s -h http://127.0.0.1:1234
```

|Thread count|reqs/s  |latency-avg|latency-stdev|latency-min|latency-max|
|-----------:|-------:|----------:|------------:|----------:|----------:|
|1           |103917  |2.46ms     |0.70ms       |1.30ms     |39.00ms    |
|2           |184753  |1.38ms     |0.47ms       |0.05ms     |39.60ms    |
|4           |216203  |1.18ms     |0.46ms       |0.04ms     |42.49ms    |
|6           |208420  |1.23ms     |0.48ms       |0.04ms     |35.80ms    |
|8           |205969  |1.24ms     |0.53ms       |0.05ms     |50.64ms    |

(The benchmark source code - it's a just a rough sketch! - is
[here](https://github.com/digital-fabric/uringmachine/blob/main/benchmark/http_server_multi_accept.rb).)

So, putting aside the fact this sketch of a web server doesn't do any CPU-bound
work, like rendering templates, for example, we can see that we can more than
double the throughput if we spread the workload over multiple threads. What I
also find interesting is that the latency numbers actually improve as we go
beyond a single thread. But, as we saw in the benchmarks above, we finally hit
diminishing returns as we continue to increase the number of threads.

## The Sidecar Thread Scenario

Another possibility that occured as I thought about combining threads and
fibers, is a sidecar setup, where we have one thread that runs the fibers, and
an auxiliary, or sidecar, thread that calls the kernel on behalf of the primary
thread.

In this setup, we have a single UringMachine instance running on a primary,
handling the workload in multiple fibers, and it's basically CPU-bound. The
UringMachine instance starts an auxiliary thread that runs in a loop, invoking
the `io_uring_enter` system call repeatedly in order to submit new I/O
operations, and processing completions as they arrive.

It remains to be seen how this will perform, and hopefully I'll be able to
report on this next week.

## Better Buffer Management in UringMachine

My work on vectorized write/send this week also ties in with the future work I
intend to do on buffer management. To make a long story short, io_uring provides
the possibility to register buffer rings where the application can create
multiple buffer rings and then dynamically add buffers to those buffer rings for
them to be used for sending or receiving to sockets.

UringMachine already supports setting up buffer rings, but in a somewhat
primitive form: to use a buffer ring you need to first call
`UM#setup_buffer_ring`, which takes a buffer size and a buffer count and returns
a buffer group id. You can then use this buffer group to receive messages
from a socket:

```ruby
# setup a buffer ring 1024 buffers with a size of 64KB each:
bgid = machine.setup_buffer_ring(1 << 16, 1024)

# receive using the buffer ring:
machine.recv_each(fd, bgid, 0) { |buffer| process_msg(buffer) }
```

What's nice about this is that you can setup a single buffer ring and use it to
receive on multiple sockets at once. You can also send messages with buffer
rings but it seems to me that this has limited utility since you cannot use a
single buffer ring to send on multiple sockets at once. That's why I did the
work on vectorized write/send, which performs similarly to `send_bundle`, which
uses buffer rings.

My plan is to provide an API to make the buffer management completely
transparent, so you'll be able to setup a buffer pool, which will automatically
manage buffer groups. It will also automatically  add and reuse buffers as
needed. It will probably look something like this:

```ruby
machine = UM.new
# setup a buffer pool that allocates 64KB buffers
buffer_pool = UM::BufferPool.new(machine, buffer_size: 1 << 16)
...
machine.recv_each(fd, buffer_pool) { process_message(it) }
```

The idea is to minimize buffer allocations by reusing buffers as much as
possible. In more recent kernels, io_uring can optimize buffer use by being able
to partially use buffers, so even if we allocate large buffers, they will be
incrementally consumed by io_uring.

## Conclusion

In just five days, we'll all get a very nice Christmas gift - Ruby 4.0! If you
want to get a sense of all the good stuff that's arriving, just take a look at
the [activity](https://github.com/ruby/ruby/pulls) on the `ruby/ruby` repo.
There's so many bug fixes and so many improvements on there, it's really
mind-boggling.

What I intend to do next week, between spending time with the family and seeing
friends, is to continue to explore the combination of threads and fibers, and to
start working on my idea for a fiber pool for automatically managing buffers for
reading/receiving.

Beyond that, beginning in January I plan to start working on OpenSSL integration
in UringMachine. I already have some ideas on how to do this, but we'll discuss
them when the time arrives.

Merry Christmas!
