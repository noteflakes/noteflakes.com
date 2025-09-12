---
title: "P2 is the New Papercraft"
layout: article
---

In the last few months I've been busy working on a few different open-source
projects. Some of those projects are still at a preliminary stage, and I'm
taking my time in continuing to develop them, use them ( [on this
website](/about) for example), but one project I've devoting a lot of attention
to is P2, a Ruby gem for writing HTML templates in plain Ruby, which I've been
writing [about](/articles/2025-08-07-introducing-p2)
[lately](/articles/2025-08-18-how-to-make-ruby-faster).

P2 has started as an exploration of how to make Papercraft faster. Papercraft,
about which I've [also written](/articles/2022-02-04-papercraft), was centered
on the idea that HTML templates should be fun to read and write, and fun to
compose in various ways, following the idea of promoting developer happiness, a
central tenet in the Ruby community.

While I absolutely adore making tools that are fun to use, I also very much like
maximizing performance in the different projects I develop. And benchmarks I did
showed me that Papercraft's performance was somewhat lacking. That is why at a
certain point I started looking at how to improve Papercraft's performance, and
I started to explore the idea of doing some kind of transformation (or
compilation) of templates in order to make rendering them faster. While I had a
general idea of how to do this (by parsing the template's source code, then
transforming the AST, and finally converting it back to source code), and have
made sketches that showed this could work, I was not sure about how to integrate
all this work into Papercraft.

Fast-forward to a few months ago, after some discussions with [Joel
Drapper](https://github.com/joeldrapper/), who's the author of
[Phlex](https://www.phlex.fun/) and who also is interested in using the same
techniques to compile Phlex templates to make them faster, I've decided to see
if I could look again at this problem, but without the baggage of an
already-existing codebase.

As an aside, this idea of *re*-examining old ideas, old codebases, and old
assumptions, is something I've been doing more and more of lately. Basically, I
try to take a certain functionality which is already implemented in a project,
and try to see if I can rethink it, and see if I can arrive at something that is
simpler, has less lines of code, works faster, more robust, and has less
dependencies.

So that's how P2 started - it was a reimagining of a HTML-generation Ruby DSL
that is *always* compiled. After a few months of work, I got P2 to where I
wanted it to be in terms of performance, namely it is now as fast as ERB, and
this is because finally the "compiled" HTML generation source code is almost
identical between P2, ERB and ERubi.

So now that P2 is *done* more or less, it's time to fold this work back into
Papercraft, and concentrate on further improving the developer experience.
There's some work I've already done on being able to inject HTML attributes into
the rendered HTML, in order to allow the implementation of frontend template
debugging tools, such as those recently shown by Marco Roth in
[ReactionView](https://reactionview.dev/). And since finally, the Papercraft/P2
templates go through a process of conversion and transformation of AST's, other
future directions Marco's talking about, such as reactive templates, are also
possible.

Now it's time to turn my attention to my other projects, which I'll write about
in the coming months. Meanwhile, please feel free to take
[Papercraft](https://github.com/digital-fabric/papercraft) for a ride. It's
really fun to use.