---
title: "About that monkey-patching business..."
date: 2021-11-04
layout: article
---

A few days ago, a
[comment](https://www.reddit.com/r/ruby/comments/qj4s94/async_ruby/hio5k1o/?utm_source=share&utm_medium=web2x&context=3)
was made on the internet about
[Polyphony](https://github.com/digital-fabric/polyphony), an open source project
of mine, mentioning the fact that Polyphony patches some core Ruby APIs. The
context was the difference between Polyphony and
[Async](https://github.com/socketry/async) (another fiber-based concurrency gem
for Ruby):

> Last time I checked, polyphony monkey patched Ruby core methods to do its work
> :-/. This has deterred from learning more about polyphony... On the other
> hand, `async` gem has always had incredibly clean code.

I'm sure Bruno Sutic, the author of the above comment, was writing in good
faith, but his comment implies that Polyphony's code is "dirty". It also implies
that monkey-patching is somehow illegitimate. While normally I don't get too
excited about people calling my code names, I do take pride in my work, and I
feel a rebuttal is in order.

<img class="med" src="https://imgs.xkcd.com/comics/duty_calls.png">

Moreover, the mere fact that Polyphony employs a (somewhat) controversial
technique to do its thing should not *deter* people like Bruno from examining
it. I'm sure all of us would benefit from approaching other people's code with
an open and inquisitive mind.

In this article I'll explain in detail the strategy I chose for developing
Polyphony and the role monkey-patching plays within it. I'll also discuss the
potential problems raised by the practice of monkey-patching, and how they can
be minimized.

## What is monkey-patching?

But first, for those that are confused about what monkey-patching actually is,
here's the [Wikipedia entry](https://en.wikipedia.org/wiki/Monkey_patch) (go
ahead, read it!) For the sake of the present discussion, I'll define
monkey-patching as the practice of changing or extending the behavior of
pre-existing Ruby classes or modules by overriding their instance or class
methods. This can be done in a variety of ways, depending on what you want to
achieve. The most obvious way would be to open the class, then *redefine* some
methods:

```ruby
class String
  def to_i
    42
  end
end

'123'.to_i #=> 42
```

You can also put your patched methods in a separate module, then
[`prepend`](https://rubyapi.org/3.0/o/module#method-i-prepend) it to the target
class (that way it will take precedence over existing method definitions):

```ruby
module StringPatches
  def to_i
    42
  end
end

String.prepend StringPatches

'123'.to_i #=> 42
```

If you need to target specific object instances, you can patch their singleton
class:

```ruby
s = '123'
class << s
  def to_i
    42
  end
end

s.to_i #=> 42
```

You can also limit the monkey-patching to a single file, class, or module, by
using
[refinements](https://docs.ruby-lang.org/en/3.0.0/doc/syntax/refinements_rdoc.html):

```ruby
module StringPatches
  refine String do
    def to_i
      42
    end
  end
end

using StringPatches # activate refinement

'123'.to_i #=> 42
```

So monkey-patching can be done in a variety of ways in Ruby, depending on how
specific you want the patched behaviour to be: from the level of a single object
instance, through specific scopes, all the way to patching classes globally.

It's also worth noting that there are other techniques that could be used
instead of monkey-patching: subclassing is ubiquitous in Ruby, and can even work
for extending core Ruby classes. Rails's
[`HashWithIndifferentAccess`](https://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html)
is a case in point. I could probably come up with a bunch of other alternatives,
but I'll leave it at that. The point is, it really depends on the circumstances.

## Is monkey-patching inherently bad?

I'm sure many people have written before about monkey-patching and whether it's
good or bad for you, but in my most humble opinion, there's no right or wrong
when it comes to programming. Monkey-patching is just a technique that has its
place like everything else under the heavens.

Of course, monkey-patching can lead to problems - it can cause compatibility
issues and strange bugs, for example when your monkey-patching gem is combined
with other gems. It can break behaviour across different versions of Ruby, or in
conjunction with specific versions of specific dependencies. It can cause all
kinds of havoc. But it can also provide a very elegant solution in specific
circumstances, and can be amazingly effective.

## When is monkey-patching useful?

Monkey-patching is useful when you need to alter or extend the way pre-existing
classes behave. Ruby's open nature lets you change almost everything about Ruby,
even core classes such as `Array` or `String` can be modified (as shown in the
above examples.) Why would we want to do this? Here are some cases where
monkey-patching can be useful:

- Ensuring compatibility between different versions of Ruby. This is especially
  useful when you need to backport some new method introduced in a later version
  of Ruby to an earlier version of Ruby. This is commonly called "polyfill"
  (there's a whole bunch of them on
  [rubygems.org](https://rubygems.org/search?query=polyfill).)
- "Fixing" some gem to work with your code. Suppose you have encountered a bug
  in some gem your project depends on. In some cases, despite everybody's best
  intentions, fixes to those problems can sometimes take months find their way
  into a new version. In those cases, a monkey-patch can solve the problem
  immediately, even if only temporarily, the new version containing the fix is
  put out by the gem's author.
- Debugging an application's behaviour by overriding methods and adding tracing,
  for example:

  ```ruby
  require 'socket'

  class TCPServer
    alias_method :orig_initialize, :initialize
    def initialize(hostname, port)
      puts "Connecting to #{hostname}:#{port}"
      orig_initialize(hostname, port)
      puts "Connected to #{hostname}:#{port}"
    end
  end
  ```

- Otherwise extending or replacing behaviours provided by the Ruby core or
  stdlib, or by Ruby gems. For example, the [`oj`](http://www.ohler.com/oj/)
  gem, which provides fast JSON processing, has a [compatibility
  mode](http://www.ohler.com/oj/doc/file.JsonGem.html) that effectively patches
  the `json` gem to provided as part of Ruby's stdlib. This feature lets Ruby
  apps take advantage of faster JSON processing without any change to their
  code.

  It's important to note that the advantage monkey-patching provides over other
  techniques, such as subclassing, is that those patches are in fact going to
  impact all the other dependencies of your app. In the case of the `oj` gem,
  any other dependencies that make use of the `JSON` API are also going to show
  improved performance!

## Designing Polyphony

When I first started working on Polyphony, I didn't know where it would take me.
Polyphony began as an experiment in designing an API for writing concurrent Ruby
programs. My starting point was the [nio4r](https://github.com/socketry/nio4r)
gem, which implements an event loop based on
[libev](http://pod.tst.eu/http://cvs.schmorp.de/libev/ev.pod). I really liked
what nio4r was able to do, and wanted to experiment with different concurrency
models, so I took its C-extension code and start fiddling with it. I went
through a whole bunch of different designs: callbacks, promises, futures,
async/await, and finally fibers.

As Polyphony slowly took form, the following principles manifested themselves:

- Polyphony should extend the Ruby runtime and feel like an integral part of it.
- Polyphony's API should allow expressing concurrent operations in a concise
  manner, with a minimum of abstractions or boilerplate.
- Polyphony should allow developers to continue working with core and stdlib
  classes and APIs such as `IO`, `Socket` and `Net::HTTP`.

In order to be able to apply the above principles to Polyphony's design, I
needed a way to make Ruby's core classes, especially those having to do with
I/O, usable under Polyphony's concurrency model. The only solution that would
have allowed me to do that was  monkey-patching all those classes, including the
`IO` class, the different `Socket` classes, even the `OpenSSL` classes dealing
with I/O. Without monkey-patching, Polyphony as it currently is would have been
impossible to implement!

## Polyphony and Ruby's new fiber scheduler interface

At this point people might ask: what about using the new
[`Fiber::SchedulerInterface`](https://rubyapi.org/3.0/o/fiber/schedulerinterface)
introduced in Ruby 3.0?  Presumably, with the `Fiber::SchedulerInterface` I
would be able to keep the same design based on the same principles, without
resorting to monkey-patching Ruby core classes. That's because the fiber
scheduler is baked right into Ruby's core.

I have long thought about this problem, and have always come to the same
conclusion: if I were to base Polyphony on the `Fiber::SchedulerInterface`, it
would have limited what Polyphony could do. In fact, some of the features
Polyphony currently offers would have been impossible to achieve:

- I want Polyphony to work on older versions of Ruby. In fact, one of my
  original constraints for developing Polyphony was to have it work on Ruby >=
  2.6 (I started work in Polyphony in August 2018.)
- Polyphony's design is highly-integrated - from the io_uring- or libev-based
  backend through the fiber-scheduling code, all the way to the developer-facing
  APIs for spinning up fibers and controlling them. Polyphony's io_uring backend
  in particular offers unique capabilities, such as chaining of I/O operations,
  which might have been much more difficult to achieve had it been based on the
  fiber scheduler interface.
- The `Fiber::SchedulerInterface` itself is still in a state of flux, and is
  still missing hooks for socket operations (according to [Samuel
  Williams](https://github.com/ioquatix), the developer behind the fiber
  scheduler interface, the `read` and `write` hooks are considered experimental
  at the moment.)
- The `Fiber::SchedulerInterface` will not magically bring fiber-awareness to
  all Ruby gems, especially not those implemented as C-extensions. Take for
  example the [pg](https://github.com/ged/ruby-pg) gem, which has recently added
  [support for fiber schedulers](https://github.com/ged/ruby-pg/pull/397).
  Compare that with Polyphony's [monkey-patching
  approach](https://github.com/digital-fabric/polyphony/blob/master/lib/polyphony/adapters/postgres.rb),
  which is much more minimal. Another example is Polyphony's [patch for
  the `redis` gem](https://github.com/digital-fabric/polyphony/blob/master/lib/polyphony/adapters/redis.rb).

  Even gems that do not rely on C-extensions might be problematic. Such is the
  case with ActiveRecord, which does connection pooling *per thread* and is thus
  apparently incompatible with both Async and Polyphony. Here again, it seems to
  me that monkey-patching might be the more effective solution, and perhaps also
  simpler to implement, at least in the short term. That's how Polyphony
  implements [fiber-aware connection
  pooling](https://github.com/digital-fabric/polyphony/blob/master/lib/polyphony/adapters/sequel.rb)
  for Sequel (thanks [wjordan](https://github.com/wjordan)!)

Integrating fiber scheduling into Ruby's core is not a trivial undertaking (and
I applaud Samuel for his resolve and determination in the face of substantial
pushback.) The problem is not only technological - making fiber scheduling work
with the complex code of Ruby's IO core - but also getting other Ruby core
developers and gem authors to understand the merits of this effort, and finally
to put out new fiber-aware versions of their code.

As the fiber scheduler interface matures, I guess I will have to reconsider my
position regarding Polyphony. One interesting
[suggestion](https://github.com/digital-fabric/polyphony/issues/46) was to
implement Polyphony as a fiber scheduler for Ruby >= 3.0, and as a "polyfill"
for earlier Ruby versions.

## What about compatibility?

Monkey-patching does introduce the problem of compatibility, and this *should*
be taken seriously. Polyphony aims to reduce compatibility issues in two ways.
firstly, Polyphony aims to mimic the same behaviour as much as possible across
all monkey-patched APIs from the point of view of the application. Secondly,
Polyphony aims to monkey-patch mostly stable APIs that have little chance of
changing between versions.

This approach is not without problems. For example, the changes to `irb`
introduced in Ruby 2.7 have broken Polyphony's patch, and there's an
[outstanding issue](https://github.com/digital-fabric/polyphony/issues/5) for it
(I'll get to it eventually.)

Polyphony also provides, as described above, mokey-patches for third-party gems,
such as `pg`, `redis` and others. Those are are bundled as part of Polyphony,
but in the futre might be extracted to separate gems, in order to be able to
respond more quickly to local issues that arise in integrating those gems with
Polyphony.

I'd also like to note that I do not expect people to just add Polypony to their
`Gemfile` and start spinning up fibers all over the place. In fact, using
Polyphony is to me such a radical shift from previous approaches to Ruby
concurrency that I find it improbable that one day it will *simply work* with
any Ruby on Rails app. Using Polyphony to its full potential will require much
more careful consideration on the part of developers using it.

I'd also like to add that my goal is not for Polyphony to become *the* solution
for fiber-based concurrency in Ruby. It's just a project that I find useful for
my own work and I feel could be useful for others as well. There's nothing wrong
with having multiple solutions to the same problem. On the contrary, I find it
beneficial and stimulating to have competing projects based on different
approaches.

## So what does Polyphony patch?

Polyphony replaces whole parts of the Ruby core API with fiber-aware code that
provides the same functionality, but integrated with Polyphony's code. I took
great care to make method signatures are the same and behave identically as much
as possible.

It's worth noting that running Ruby programs with multiple fibers
present challenges that go beyond merely reading and writing to `IO` instances:
there's all kinds of subtleties around forking, signal handling, waiting for
child processes and thread control. Much of the monkey-patching that Polyphony
performs is around that.

Here's a (probably incomplete) list of APIs monkey-patched by Polyphony:

- `IO` - all read/write instance methods and all read/write class methods
- `Socket`/`TCPSocket`/`TCPServer` et al - all I/O functionality including `accept` and `connect`
- `OpenSSL::SSL::SSLSocket`/`OpenSSL::SSL::SSLSocket` - all `read`/`write`/`accept`/`connect` methods
- `Kernel` - methods such as `sleep`, \` (backtick) , `system`, `trap`
- `Process#detach`
- `Timeout#timeout`
- `Thread#new` and `Thread#join`

Polyphony also provides monkey-patches for gems such as `pg`, `redis`, `mysql2`
and `sequel`.

## Conclusion

Polyphony uses monkey-patching extensively because it's the best way to
achieving the goals I set to myself in developing it. Yes, monkey-patching has
its disadvantages, but it also has advantages (as I showed above). Finally, I
believe Polyphony should be rather judged by what it can do, and by the value it
provides to developers.