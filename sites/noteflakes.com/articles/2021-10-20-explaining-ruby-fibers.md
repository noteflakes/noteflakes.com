---
title: "Explaining Ruby Fibers"
layout: article
---

Fibers have long been a neglected corner of the Ruby core API. Introduced in
Ruby version 1.9 as a coroutine abstraction, fibers have never really seemed to
realize their promise of lightweight concurrency, and remain relatively little
explored. In spite of attempts to employ them for achieving concurrency, most
notably [em-synchrony](https://github.com/igrigorik/em-synchrony), fibers have
not caught on. Hopefully, with the advent of the
[FiberScheduler](https://rubyapi.org/3.0/o/fiber/schedulerinterface) interface
introduced in Ruby 3.0, and libraries such as
[Async](https://github.com/socketry/async) and
[Polyphony](https://github.com/digital-fabric/polyphony), this situation will
change and fibers will become better known and understood, and Ruby developers
will be able to use them to their full potential.

My aim in this article is to explain how fibers work from the point of view of a
concurrent Ruby application written using Polyphony. I'll give an overview of
fibers as concurrency constructs, and discuss how Polyphony harnesses Ruby
fibers in order to provide an idiomatic and performant solution for writing
highly-concurrent Ruby apps. For the sake of simplicity, I'll omit some details,
which will be mentioned in footnotes towards the end of this article.

## What's a Fiber?

Most developers (hopefully) know about threads, but just what are fibers?
Linguistically we can already tell they have some relation to threads, but what
is the nature of that relation? Is it one of aggregation (as in "a thread is
made of one or more fibers",) or is it one of similitude (as in "a fiber is sort
of like a thread but lighter/smaller/whatever"?) As we shall see, it's
a little bit of both.

A fiber is simply an independent execution context that can be paused and
resumed programmatically. We can think of fibers as story lines in a book or a
movie: there are multiple happenings involving different persons at different
places all occurring at the same time, but we can only follow a single story
line at a time: the one we're currently reading or watching.

This is one of the most important insights I had personally when I started
working with Ruby fibers: there's always a currently active fiber. In fact, even
if you don't use fibers and don't do any fiber-related work, your code is still
running in the context of the main fiber for the current thread, which is
created automatically by the Ruby runtime *for each thread*.

So a fiber is an execution context, and in that regard it's kind of like a
thread: it keeps track of a sequence of operations, and as such it has its own
stack and instruction pointer. Where fibers differ from threads is that they are
not managed by the operating system, but instead are paused, resumed, and
switched between by the userspace program itself. This programmatic way to
switch between different execution contexts is also called "cooperative
multitasking", in contrast to the way threads are being switched by the
operating system, called "preemptive multitasking".

## Switching between Fibers

Here's a short example of how switching between fibers is done[¹](#f1). In this
example we're doing the fiber switching manually:

```ruby
require 'fiber'

@f1 = Fiber.new do
  puts 'Hi from f1'
  @f2.transfer
  puts 'Hi again from f1'
end

@f2 = Fiber.new do
  puts 'Hi from f2'
  @f1.transfer
end

puts 'Hi from main fiber'
@f1.transfer
puts 'Bye from main fiber'
```

In the above example, we create two fibers. The main fiber then transfers
control ("switches") to fiber `@f1`, which then transfers control to `@f2`,
which then returns control to `@f1`. When `@f1` has finished running, control is
returned automatically to the main fiber, and the program terminates. The
program's output will be:

```
Hi from main fiber
Hi from f1
Hi from f2
Hi again from f1
Bye from main fiber
```

One peculiarity of the way switching between fibers is done, is that the context
switch is always initiated from the currently active fiber. In other words, the
currently active fiber must voluntarily yield control to another fiber. This is
also the reason why this model of concurrency is called "cooperative
concurrency."

Another important detail to remember is that a fiber created using `Fiber.new`
always starts in a suspended state. It will not run unless you first switch to
it using `Fiber#transfer`.

## Controlling fiber state via the context switch

What I find really interesting about the design of Ruby fibers is that the act
of pausing a fiber, then resuming it later, is seen as a normal method call from
the point of view of the fiber being resumed: we make a call to
`Fiber#transfer`, and that call will return only when the fiber who made that
call is itself resumed using a reciprocal call to `Fiber#transfer`. The return
value will be the value given as an argument to the reciprocal call, as is
demonstrated in the following example:

```ruby
ping = Fiber.new do |peer|
  loop do
    msg = peer.transfer('ping')
    puts msg
  end
end

pong = Fiber.new do |msg|
  loop do
    puts msg
    msg = ping.transfer('pong')
  end
end

ping.transfer(pong)
```

The block provided to `Fiber.new` can take a block argument which will be set to
the value given to `Fiber#transfer` the first time the fiber is being resumed.
We use this to set `ping`'s peer, and then use `Fiber#transfer` to pass messages
between the `ping` and `pong` fibers.

This characteristic of `Fiber#transfer` has profound implications: it means that
we can control a fiber's state using the value we pass to it as we resume it.
Here's an example for how this could be done:

```ruby
main = Fiber.current
f = Fiber.new do |msg|
  count = 0
  loop do
    case msg
    when :reset
      count = 0
    when :increment
      count += 1
    end
    puts "count = #{count}"
    msg = main.transfer
  end
end

3.times { |i| f.transfer(:increment) } # count = 3
f.transfer(:reset)                     # count = 0 
3.times { |i| f.transfer(:increment) } # count = 3
```

In the above example, the fiber `f` gets its state updated each time it is
resumed. The main fiber can control `f`'s state by passing a special value when
calling `Fiber#transfer`. As long as we have in place a well-defined convention
for how the transferred value is interpreted by fibers in a given program, we
can implement arbitrarily complex semantics for controlling our fibers' state
and life-cycle. Later on in this article we'll see how Polyphony couples this
mechanism with return values from blocking operations, as well as exceptions
that permit us to cancel any long-running operation at any time.

## Switching fibers on long-running operations

Now that we have a feel for how fibers can be paused and resumed, we can discuss
how this can be used in conjunction with blocking operations. For the sake of
our discussion, a blocking operation is any operation that potentially needs to
wait for some external event to occur, such as a socket becoming readable, or
waiting for a timer to elapse. We want to be able to have multiple concurrent
tasks, each proceeding at its own pace, and each yielding control whenever it
needs to wait for some external event to occur.

In order to demonstrate how this might work, let's imagine a program where we
have two fibers: one waits for data to arrive on STDIN, then echoes it; and a
second fiber that prints the time once a second:

```ruby
@echo_printer = Fiber.new do
  loop do
    if STDIN.readable?
      msg = STDIN.readpartial(1024)
      puts msg
    end
    @time_printer.transfer
  end
end

@time_printer = Fiber.new do
  timer = Timer.new(1)
  loop do
    if timer.elapsed?
      puts "Time: #{Time.now}"
      timer.reset
    end
    @echo_printer.transfer
  end
end
```

In each of the above fibers, we have have a condition that tells us if the fiber
can proceed: for `@echo_printer` the condition is `STDIN.readable?`; for
`@time_printer` it's `timer.elapsed?`. What's notable though about this example
that the switching between fibers is done *explicitly*, and that each fiber
needs to check a condition continually. Of course, this is not ideal, since the
two fibers will just pass control between them until one of the conditions is
met and actual work is done. If you run such a program, you'll see one of your
CPU cores saturated. But the main insight to draw here is that each fiber can
yield control to another fiber if it cannot go on doing actual work.

## Automatic fiber switching using an event reactor

Let's see if we can avoid endlessly checking for readiness conditions, by using
an event reactor - a piece of software that lets you subscribe to specific
events, most importantly I/O readiness, and timers. In this case we'll be using
[ever](https://github.com/digital-fabric/ever), a tiny Ruby gem that I wrote a
few months ago, implementing an event reactor for Ruby apps based on
[libev](http://pod.tst.eu/http://cvs.schmorp.de/libev/ev.pod). Here's our
rewritten example:

```ruby
require 'ever'
require 'fiber'

evloop = Ever::Loop.new
@reactor = Fiber.current

@echo_printer = Fiber.new do
  loop do
    msg = STDIN.readpartial(1024)
    puts msg
    @reactor.transfer
  end
end

@time_printer = Fiber.new do
  loop do
    puts "Time: #{Time.now}"
    @reactor.transfer
  end
end

# register interest in events
evloop.watch_io(@echo_printer, STDIN, false, false)
evloop.watch_timer(@time_printer, 1, 1)

# run loop
evloop.each { |fiber| fiber.transfer }
```

As you can see, our fibers no longer need to check for readiness. The reactor,
after registering interest in the respective event for each fiber, runs the
event loop, and when an event becomes available, the corresponding fiber is
resumed. Once resumed, each fiber does its work, then yields control back to the
reactor.

This is already a great improvement, since our program does not need to
endlessly check for readiness, and the code for each of the fibers doing actual
work looks almost normal. The only sign we have of anything "weird" going on is
that each fiber needs to yield control back to the reactor by calling
`@reactor.transfer`.

If we look more closly at the above program, we can describe what's actually
happening as follows:

```ruby
@echo_printer = Fiber.new do
  loop do
    msg = STDIN.readpartial(1024)
    puts msg

    wait_for_events if queued_events.empty?
    queued_events.each { |e| e.fiber.transfer }
  end
end

@time_printer = Fiber.new do
  loop do
    puts "Time: #{Time.now}"
    
    wait_for_events if queued_events.empty?
    queued_events.each { |e| e.fiber.transfer }
  end
end

...
```

For each of our fiber, at any point where the fiber needs to wait, we first look
at our list of queued events. If there are none, we wait for events to occur.
Finally we proceed to handle those events by transferring control to each
respective fiber. This needs to be done for each blocking or long-running
operation: reading from a file, reading from a socket, writing to a socket,
waiting for a time period to elapsed, waiting for a process to terminate, etc.
What if we had a tool that could automate this for us? This is where Polyphony
enters the stage.

## Using Polyphony for fiber-based concurrency

Polyphony automates all the different aspects of fiber switching, which boils
down to knowing which fiber should be running at any given moment. Let's see how
Polyphony solves the problem of fiber switching by using it to rewrite the
example above:

```ruby
require 'polyphony'

echo_printer = spin do
  loop do
    msg = STDIN.read
    puts msg
  end
end

time_printer = spin do
  loop do
    sleep 1
    puts "Time: #{Time.now}"
  end
end

Fiber.await(echo_printer, time_printer)
```

As our rewritten example shows, we got completely rid of calls to
`Fiber#transfer`. The fiber switching is handled automatically and implicitly by
Polyphony[²](#f2). Each fiber is an autonomous [infinite
loop](/articles/2021-10-14-embracing-infinite-loops) made of a sequence of
operations that's simple to write and simple to read. All the details of knowing
when `STDIN` is ready or when a second has elapsed, and which fiber to run at
any moment, are conveniently taken care of by Polyphony.

Even more importantly, Polyphony offers a fluent, idiomatic API that mostly gets
out of your way and feels like an integral part of the Ruby core API. Polyphony
introduces the `#spin` global method, which creates a new fiber and schedules it
for running as soon as possible (remember: fibers start their life in a
suspended state.) The call to `Fiber.await` means that the main fiber, from
which the two other fibers were spun, will wait for those two fibers to
terminate. Because both `echo_printer` and `time_printer` are infinite loops,
the main fiber will wait forever.

Now that we saw how Polyphony handles behind the scenes all the details of
switching between fibers, let's examine how Polyphony does that.

## The fiber switching dance

A fiber will spend its life in one of three states: `:running`, `:waiting` or
`:runnable`[³](#f3). As discussed above, only a single fiber can be `:running` at a
given moment (for each thread). When a fiber needs to perform a blocking
operation, such as reading from a file descriptor, it makes a call to the
Polyphony backend associated with its thread, which performs the actual I/O
operation. The backend will submit the I/O operation to the OS (using the
[io_uring](https://unixism.net/loti/what_is_io_uring.html) interface[⁴](#f4),) and will
switch to the first fiber pulled from the *runqueue*, which will run until it
too needs to perform a blocking operation, at which point another fiber switch
will occur to the next fiber pulled from the runqueue.

Meanwhile, our original fiber has been put in the `:waiting` state. Eventually,
the runqueue will be exhausted, which means that all fibers are waiting for some
event to occur. At this point, the Polyphony backend will check whether any of
the currently ongoing I/O operation have completed. For each completed
operation, the corresponding fiber is "scheduled" by putting it on the runqueue,
and the fiber transitions to the `:runnable` state. The runnable state means
that the operation the fiber was waiting for has been completed (or cancelled),
and the fiber can be resumed.

Once all completed I/O operations have been processed, the backend performs a
fiber switch to the first fiber available on the runqueue, the fiber transitions
back to the `:running` state, and the whole fiber-switching dance recommences.

What's notable about this way of scheduling concurrent tasks is that Polyphony
does not really have an event loop that wraps around your code. Your code does
not run inside of a loop. Instead, whenever your code needs to perform some
blocking operation, the Polyphony backend starts the operation, then switches to
the next fiber that is `:runnable`, or ready to run.

## The runqueue

The runqueue is simply a FIFO queue that contains all the currently runnable
fibers, that is fibers that can be resumed. Let's take our last example and
examine how the contents of the runqueue changes as the program executes:

```ruby
runqueue #=> []

echo_printer = spin { ... }
runqueue #=> [echo_printer]

time_printer = spin { ... }
runqueue #=> [echo_printer, time_printer]

# at this point the two fibers have been put on the runqueue and will be resumed
# once the current (main) fiber yields control:
Fiber.await(echo_printer, time_printer)

# while the main fiber awaits, the two fibers are resumed. echo_printer will
# wait for STDIN to become readable. time_printer will wait for 1 second to
# elapse.

# The runqueue is empty.
runqueue #=> []

# Since there's no runnable fiber left, the Polyphony backend will wait for
# io_uring to generate at least one completion entry. A second has elapsed, and
# time_printer's completion has arrived. The fiber becomes runnable and is put
# back on the runqueue.
runqueue #=> [time_printer]

# Polyphony pulls the fiber from the runqueue and switches to it. The time is
# printed, and time_printer goes back to sleeping for 1 second. The runqueue is
# empty again:
runqueue #=> []

# The Polyphony backend waits again for completions to occur. The user types a
# line and hits RETURN. The completion for echo_printer is received, and
# echo_printer is put back on the runqueue:
runqueue #=> [echo_printer]

# Polyphony pulls the fiber from the runqueue and switches to it.
runqueue #=> []

...
```

While the runqueue was represented above as a simple array of runnable fibers,
its design is actually much more sophisticated than that. First of all, the
runqueue is implemented as a [ring
buffer](https://github.com/digital-fabric/polyphony/blob/master/ext/polyphony/runqueue_ring_buffer.c)
in order to achieve optimal performance. The use of a ring buffer algorithm
results in predictable performance characteristics for both adding and removing
of entries from the runqueue. When adding an entry to a runqueue that's already
full, the underlying ring buffer is reallocated to twice its previous size. For
long running apps, the runqueue size will eventually stabilize around a value
that reflects the maximum number of currently runnable fibers in the process.

In addition, each entry in the runqueue contains not only the fiber, but also
the value with which it will be resumed. If you recall, earlier we talked about
the fact that we can control a fiber's state whenever we resume it by passing it
a value using `Fiber#transfer`. The fiber will receive this value as the return
value of its own previous call to `Fiber#transfer`.

In Polyphony, each time a fiber is resumed, the return value is checked to see
if it's an exception. In case of an exception, it will be raised in the context
of the resumed fiber. Here's an excerpt from Polyphony's [io_uring
backend](https://github.com/digital-fabric/polyphony/blob/master/ext/polyphony/backend_io_uring.c)
that implements the global `#sleep` method:

```c
VALUE Backend_sleep(VALUE self, VALUE duration) {
  Backend_t *backend;
  GetBackend(self, backend);

  VALUE resume_value = Qnil;
  io_uring_backend_submit_timeout_and_await(backend, NUM2DBL(duration), &resume_value);
  RAISE_IF_EXCEPTION(resume_value);
  RB_GC_GUARD(resume_value);
  return resume_value;
}
```

In the code above, we first submit an iouring timeout entry, then yield
control (by calling `Fiber#transfer` on the next runnable fiber) and await its
completion. When the call to [`io_uring_backend_submit_timeout_and_await`](https://github.com/digital-fabric/polyphony/blob/89b18ce3626e253e1731e6489d59845f0a3e50cb/ext/polyphony/backend_io_uring.c#L980-L989)
returns, our fiber has alreadey been resumed, with `resume_value` holding the
value returned from our call to `Fiber#transfer`. We use [`RAISE_IF_EXCEPTION`](https://github.com/digital-fabric/polyphony/blob/89b18ce3626e253e1731e6489d59845f0a3e50cb/ext/polyphony/polyphony.h#L23-L26) to
check if `resume_value` is an exception, and raise it in case it is.

It's also important to note the resume values stored alongside fibers in the
runqueue can be used in effect to control a fiber's state, just like in bare
bones calls to `Fiber#transfer`. This can be done using the Polyphony-provided
`Fiber#schedule` method, which puts the fiber on the runqueue, along with the
provided resume value:

```ruby
lazy = spin do
  loop do
    msg = suspend
    puts "Got #{msg}"
  end
end

every(1) { lazy.schedule('O hi!') }
```

In the example above, our `lazy` fiber suspends itself (using `#suspend`, which
puts it in a `:waiting` state), and the main fiber schedules it once every
second along with a message. The lazy fiber receives the message as the return
value of the call to `#suspend`. One important difference between
`Fiber#schedule` and `Fiber#transfer` is that `Fiber#schedule` does not perform
a context switch. It simply puts the fiber on the runqueue along with its resume
value. The fiber will be resumed as soon as all previous runnable fibers have
been resumed and have yielded control.

## Yielding control

As explained above, blocking operations involve submitting the operation to the
io_uring interface, and then yielding (or `#transfer`ring) control to the next
runnable fiber. A useful metaphor here is the relay race: only a single person
runs at any given time (she holds the baton,) and eventually the runner will
pass the baton to the next person who's ready to run. Let's examine what happens
during this "passing of the baton" in a little more detail.

In effect, once the I/O operation has been submitted, the Polyphony backend
calls the
[`backend_base_switch_fiber`](https://github.com/digital-fabric/polyphony/blob/c7f670f12c386f7ae607c0a6cce5427acefd59d8/ext/polyphony/backend_common.c#L59-L105)
function, which is responsible for this little ceremony, which consists of the
following steps:

1. Shift the first runqueue entry from the runqueue.
2. If the entry is not `nil`:
  - Check if it's time to do a non-blocking poll (in order to prevent starvation
    of I/O completions. See discussion below.)
  - proceed to step 4.
3. Otherwise:
  - Perform a blocking poll.
  - Go back to step 1.
4. Transfer control to the entry's fiber with the entry's resume value using
   `Fiber#transfer`.

All this happens in the context of the fiber that yields control, until a
context switch is performed in step 4. To reuse our "relay race" metaphor, each
time the current runner wishes to pass the baton to the next one, it's as if she
has a little gadget in her hand that holds the baton, performs all kinds of
checks, finds out who the next runner is, and finally hands it over to the next
runner.

## Polling for I/O completions

When there are no runnable fibers left, Polyphony polls for at least one
io_uring completion to arrive. For each received completion, the corresponding
fiber is scheduled by putting it on the runqueue. Once the polling is done, the
first fiber is pulled off the runqueue and is then resumed.

As we saw, polling for completions is only perofrmed done when the runqueue is
empty. But what about situations where the runqueue is never empty? Consider the
following example:

```ruby
@f1 = spin { loop { @f2.schedule; puts 'f1' } }
@f2 = spin { loop { @f1.schedule; puts 'f2' } }

Fiber.await(@f1, @f2)
```

Each of the fibers above will run in an infinite loop, scheduling its peer and
then printing a message. As shown above, the call to `#puts`, being an I/O
operation, causes the Polyphony backend to submit the `write` operation to the
io_uring interface, and then perform a context switch to the next runnable
fiber. In order for the call to `#puts` to return, the Polyphony backend needs
to poll for completions from the io_uring interface. But, since the runqueue is
never empty (both fibers are scheduling each other, effectively adding each
other to the runqueue,) the runqueue will never be empty!

In order to be able to deal with such circumstances, and prevent the
"starvation" of completion processing, the Polyphony backend periodically
performs a non-blocking check for any received completions. This mechanism
assures that even in situations where our application becomes CPU-bound (since
there's always some fiber running!) we'll continue to process io_uring
completions, and our entire process will continue to behave normally.

## Implications for performance

The asynchronous nature of the io_uring interface has some interesting
implications for the performance of Polyphony's io_uring backend. As mentioned
above, the submission of SQE's is deferred, and performed either when a certain
number of submissions have acumulated, or before polling for completions.

In Polyphony, runnable fibers are always prioritized, and polling for events is
done mostly when there are no runnable fibers. Theoretically, this *might* have
a negative impact on latency, but I have seen the io_uring backend achieve more
than twice the throughput achieved by the libev backend. Tipi, the
Polyphony-based web server I'm currently developing, boasts a request rate of
[more than 138K
requests/second](https://github.com/digital-fabric/tipi/#benchmarks) at the time
of this writing.

In fact, Polyphony provides multiple advantages over other concurrency
solutions: The number of I/O-related syscalls is minimized (by using the
io_uring interface.) In addition, the use `Fiber#transfer` to transfer control
*directly* to the next runnable fiber halves the number of context-switches when
compared to using `Fiber#resume`/`Fiber.yield`.

Most importantly, by prioritizing runnable fibers over processing of I/O
completions (with an anti-starvation mechanism as described above,) Polyphony
lets a Ruby app switch easily between I/O-bound work and CPU-bound work. For
example, when a Polyphony-based web server receives 1000 connections in the
space of 1ms, it needs to perform a lot of work, setting up a fiber, a parser
and associated state for each connection. The design of Polyphony's scheduling
system allows the web server to do this burst of hard work while deferring any
I/O work for later submission. When this CPU-bound burst has completed, the web
server fires all of its pending I/O submissions at once, and can proceed to
check for completions.

## Cancellation

Now that we have a general idea of how Polyphony performs fiber switching, let's
examine how cancellation works in Polyphony. We want to be able to cancel any
ongoing operation at any time. This can be done for any reason: a timeout has
elapsed, an exception has occurred in a related fiber, or business logic that
requires cancelling some specific operation in specific circumstances. The
mechanism for doing this is simple, as mentioned above: we use an exception as
the resume value that will be transferred to the fiber when the context switch
occurs.

Here's a simple example that shows how cancellation looks from the app's point
of view:

```ruby
def gets_with_timeout(io, timeout)
  move_on_after(timeout) { io.gets }
end
```

The `#move_on_after` global API sets up a timer, then runs the given block. If
the timer has elapsed before the block has finished executing, the fiber is
scheduled with a `Polyphony::MoveOn` exception, any ongoing I/O operation is
cancelled by the backend, the exception is caught by `#move_on_after` and an
optional cancellation value is returned.

If we want to generate an exception on timeout, we can instead use the
`#cancel_after` API, which will schedule the fiber with a `Polyphony::Cancel`
exception, and the exception will have to be caught by the app code:

```ruby
def gets_with_timeout(io, timeout)
  cancel_after(timeout) { io.gets }
rescue Polyphony::Cancel
  "gets was cancelled!"
end
```

## More ways to control fiber execution

In addition to the various APIs discussed above, here's a list of some of the
various APIs used for controlling fiber execution:

- `#suspend` - transition from `:running` to `:waiting` state. A fiber that was
  suspended will not be resumed until it is manually scheduled.
- `#snooze` - transition from `:running` to `:runnable` state. The fiber is put
  on the runqueue, and will eventually get its turn again. This method is useful
  when a fiber performs a long-running CPU-bound operation and needs to
  periodically let other fibers have their turn.
- `Fiber#schedule` - transition from `:waiting` to `:runnable` state, with an
  optional resume value.
- `Fiber#terminate` - [terminate a
  fiber](/articles/2021-10-14-embracing-infinite-loops#more-ways-to-stop-a-fiber).

## Conclusion

Polyphony has been built to harness the full power of Ruby fibers, and provide a
solid and joyful experience for those wishing to write highly-concurrent Ruby
apps. There are many subtleties to designing a robust, well-behaving fiber-based
concurrent environment. For example, there's the problem of
[forking](https://github.com/digital-fabric/polyphony/blob/47ca56812a7b4dab7e0f0d9b13f98ce70e522ff8/lib/polyphony.rb#L24-L39)
from arbitrary fibers, or the problem of correctly handling
[signals](https://github.com/digital-fabric/polyphony/blob/47ca56812a7b4dab7e0f0d9b13f98ce70e522ff8/lib/polyphony/extensions/core.rb#L145-L161).
Polyphony aims to take care of all these details, in order to be able to handle
a broad range of applications and requirements.

I hope this article has helped clear up some of the mystery and misconceptions
about Ruby fibers. Please [let me know](/about) if you have specific questions
about fibers in general or Polyphony in particular, and feel free to browse
[Polyphony's source code](https://github.com/digital-fabric/polyphony).
Contributions will be gladly accepted!

### Footnotes

<a id="f1">1.</a> In this article we'll confine ourselves to using the
`Fiber#transfer` API for fiber switching, which is better suited for usage with
symmetric coroutines. Using the `Fiber.yield`/`Fiber#resume` API implies an
asymmetric usage which is better suited for fibers used as generators or
iterators. Sadly, most articles dealing with Ruby fibers only discuss the
latter, and make no mention of the former. Please note that in order to use
`Fiber#transfer` we first need to `require 'fiber'`.

<a id="f2">2.</a> I've mentioned above the [Fiber Scheduler
interface](https://rubyapi.org/3.0/o/fiber/schedulerinterface) introduced in
Ruby 3.0, based on the work of [Samuel Williams](https://github.com/ioquatix).
This new feature, baked into the Ruby core, has roughly the same capabilities as
Polyphony when it comes to automatically switching between fibers based on I/O
readiness. As its name suggests, this is just a well-defined interface. In order
to be able to employ it in your Ruby app, you'll need to use an actual fiber
scheduler. At the moment, the following fiber schedulers are available, in
different states of production-readiness: [evt](https://github.com/dsh0416/evt),
[event](https://github.com/socketry/event), and my own
[libev-scheduler](https://github.com/digital-fabric/libev_scheduler).

<a id="f3">3.</a> A fourth state, `:dead` is used for fibers that have terminated. A fiber's
state can be interrogated using `Fiber#state`.

<a id="f4">4.</a> Polyphony also includes an alternative backend used on non-Linux OSes or
older Linux kernels. Both backends have the same capabilities. In this article
we'll discuss only the io_uring backend.
