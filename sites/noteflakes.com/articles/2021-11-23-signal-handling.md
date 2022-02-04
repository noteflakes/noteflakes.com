---
title: Signal handling in concurrent apps with Ruby and Polyphony
layout: article
---

In the last few weeks I've been writing about different aspects of
[Polyphony](https://github.com/digital-fabric/polyphony), a library for writing
fiber-based concurrent apps in Ruby. Polyphony makes it easy for developers to
use stock Ruby core and stdlib classes and APIs in a highly-concurrent
environment in order to create scalable, high-performance apps.

In order for provide a solid developer experience, Polyphony reimplements
different parts of the Ruby runtime functionality, which are adjusted so
developers will see a consistent and reliable behaviour. In this article I'll
discuss how Polyphony implements signal handling. For the sake of brevity, I'll
assume the reader is familiar with POSIX signals and has some knowledge of how
signals are handled in Ruby.

## What happens when a signal is trapped

In order to get a clear picture of how signal traps work, here's the relevant
passage from the Linux `sigreturn` [manpage](https://www.man7.org/linux/man-pages/man2/sigreturn.2.html):

> If the Linux kernel determines that an unblocked signal is pending for a
> process, then, at the next transition back to user mode in that process (e.g.,
> upon return from a system call or when the process is rescheduled onto the
> CPU), it creates a new frame on the user-space stack where it saves various
> pieces of process context (processor status word, registers, signal mask, and
> signal stack settings).
> 
> The kernel also arranges that, during the transition back to user mode, the
> signal handler is called, and that, upon return from the handler, control
> passes to a piece of user-space code commonly called the "signal trampoline".
> The signal trampoline code in turn calls sigreturn().
>
> ... Using the information that was earlier saved on the user-space stack
> sigreturn() restores the process's signal mask, switches stacks, and restores
> the process's context (processor flags and registers, including the stack
> pointer and instruction pointer), so that the process resumes execution at the
> point where it was interrupted by the signal.

From the point of view of the developer, when a signal occurs, it's as if
control of your program has been momentarily hijacked and a special bit of
code－the signal handler block－is executed. Once the block has finished
running, control is returned to your program, which continues running normally
as if nothing happened, *unless* the signal handler has raised an exception. In
that case, the exception will be raised by the Ruby runtime in the signal
trampoline.

By default, Ruby traps the `INT` and `TERM` signals by raising `Interrupt` and
`SystemExit` exceptions, respectively. Other signals cause a `SignalException`
to be raised. Normally, such exceptions will cause the program to exit, unless
they are rescued. The following block will gracefully handle pressing ctrl-C in
the terminal:

```ruby
begin
  puts 'going to sleep...'
  sleep
rescue => Interrupt
  puts 'got Interrupt, waking up.'
end
```

In addition there are some operations that are not allowed in Ruby signal
handlers, namely acquiring mutexes (which is needed for doing buffered I/O) and
joining threads. If you need to do that in your program, you'll need to
implement your own mechanisms for handling signals asynchronously, that is,
outside of the signal handler block. Sidekiq, for example, implements a
mechanism for handling signals asynchronously by [writing to a
pipe](https://github.com/mperham/sidekiq/pull/761).

However, when your program switches constantly between multiple fibers, a signal
may occur in the context of any fiber, and if a signal exception is raised, it
might be raised in the context of any fiber. This might lead to a situation
where the exception terminates some worker fiber, and this may prevent the
graceful handling of the signal.

## Making signals work with structured concurrency

Polyphony's implementation of structured concurrency assures developers that any
exception occuring in any fiber will bubble up the fiber hierarchy if it is not
rescued locally. How can we make signal exceptions work in an multi-fiber
environment, and furthermore how can we make *any* signal handler work when we
don't know in what fiber the signal will occur?

Polyphony's answer to that is actually quite simple: it runs the signal handler
block on a new raw fiber ("raw" meaning it's not bound by Polyphony's rules of
structured concurrency.) This
[out-of-band](https://en.wikipedia.org/wiki/Out-of-band_data) fiber is
priority-scheduled by putting it at the head of the runqueue, causing it to be
run immediately once the currently running fiber has yielded control. Any
uncaught exception raised in the signal handler will be propagated to the main
fiber, which will also be priority-scheduled:

```ruby
module FiberControlClassMethods
  def schedule_priority_oob_fiber(&block)
    # Setup raw fiber
    oob_fiber = Fiber.new do
      Fiber.current.setup_raw
      block.call
    rescue Exception => e
      # Transfer uncaught exception to the main fiber by scheduling with the
      # exception as the resume value.
      Thread.current.schedule_and_wakeup(Thread.main.main_fiber, e)
    end
    # Thread#schedule_and_wakeup schedules the fiber at the head of the runqueue.
    Thread.current.schedule_and_wakeup(oob_fiber, nil)
  end
end
```

The `Thread#schedule_and_wakeup` method schedules the given fiber with priority:

```c
VALUE Thread_fiber_schedule_and_wakeup(VALUE self, VALUE fiber, VALUE resume_obj) {
  if (fiber != Qnil) {
    Thread_schedule_fiber_with_priority(self, fiber, resume_obj);
  }

  if (Backend_wakeup(rb_ivar_get(self, ID_ivar_backend)) == Qnil) {
    Thread_switch_fiber(self);
  }

  return self;
}
```

`Backend_wakeup` will return true if the Polyphony backend is currently polling
for completions (or for events if using libev instead of io_uring). If that was
the case, there's no need to take any further action, the signal handling fiber
will be switched to as soon as the polling is done (that is, right after the
signal trap has returned). If not, we call `Thread_switch_fiber` which will
immediately switch to the signal handling fiber.

In this manner, signal handling becomes asynchronous, but any received signal is
handled as soon as possible, without interfering with the work of any fiber in
your Ruby process. As a consequence, there's no more limits on what you can do
in the signal handler block provided to `Kernel#trap`.

Finally, in order to transparently handle the setting of signal traps, Polyphony
[monkey-patches](/articles/2021-11-04-monkey-patching) `Kernel#trap`:

```ruby
module Kernel
  # The actual code for this method is a bit more involved
  def trap(sig, &block)
    orig_trap(sig) do
      Fiber.schedule_priority_oob_fiber(&block)
    end
  end
end
```

## Signal handling patterns

There are some useful patterns you can employ when dealing with signals. In
general, Polyphony shies away from callbacks. Almost the entire Polyphony API is
exclusively synchronous and blocking. But when installing a signal trap, you
actually provide a callback that will be called asynchronously sometime in the
future. With Polyphony, it's easy to turn this into a blocking API.

```ruby
def await_signal(sig)
  this_fiber = Fiber.current
  trap(sig) { this_fiber.schedule }
  suspend
end

# We do work in a separate fiber
spin { do_some_work }

# On the main fiber we wait for a signal
await_signal('INT')
puts 'Got INT, quitting.'
```

If the signal handling logic is something that can happen multiple times, we can
use [fiber
messaging](/articles/2021-11-13-real-world-polyphony-chat#fiber-messaging) to
serialize the receipt of signals:

```ruby
worker = spin { do_some_work }
signal_watcher = spin_loop do
  sig = receive
  case sig
  when 'USR1'
    worker.restart
  when 'TERM'
    worker.stop
    worker.await
  when 'INT'
    exit!
  end
end

%w{USR1 TERM INT}
  .each { |sig| trap(sig) { signal_watcher << sig } }
```

## Conclusion

In this article we have explored how POSIX signals can be handled in a safe and
consistent manner in a fiber-based concurrent environment such as
[Polyphony](https://github.com/digital-fabric/polyphony). Other interesting
aspects of the behaviour of multi-fiber Ruby programs, such as forking and
exception handling, will be addressed in future articles. Please feel free to
[contact me](https://noteflakes.com/about#contact) if you have any questions
about this article or Polyphony in general.
