---
title: "You Win Some, You Lose Some: on Papercraft and more"
layout: article
---

In the last few weeks I've been busy with a few different projects, and I guess
I'm not the only freelancer who has trouble finding their work-life balance.
That is, in the last few weeks life has been hitting me in the face, and it was
a bit overwhelming. But I still did manage to make some progress on my work, and
thought I might share it here.

## Papercraft Update

Since [releasing Papercraft 3.0](/articles/2025-10-20-papercraft-3), I've been
busy preparing a talk on Papercraft for Paris.rb. To me this was a major
undertaking, since I've near-zero experience doing conference talks, and for me
this was a test of my writing abilities, as well as my talking abilities. More
on that in a moment.

I also managed to release a few more versions of Papercraft, which is now at
version 3.2.0. Here are the major changes since version 3.0:

- Fixed compilation of ternary operator expressions, so stuff like `x ?
  h1('foo') : h2('bar')` will compile correctly.
- Added an optional `Proc` API, so you could do stuff like `template.html(...)`
  instead of calling `Papercraft.html(template, ...)`. To use this API you need
  to first `require "papercraft/proc"`. This essentially restores the pre-3.0
  API, but as an opt-in.
- Added Tilt integration, so you could use Papercraft with Tilt.
  [Tilt](https://github.com/jeremyevans/tilt) is a generic interface for using
  different Ruby template engines. Here's an example of how to use it:

  ```ruby
  require 'tilt/papercraft'

  t = Tilt['papercraft'].new {
    "
      h1 locals[:a]
      p locals[:b]
      render block if block
    "
  }

  t.render(Object.new, a: 'foo', b: 'bar') {
    hr
  }
  #=> "<h1>foo</h1><p>bar</p><hr>"
  ```

## The Paris.rb Talk

It actually took me a few weeks of writing and rewritng to finally arrive at a
talk that I found both interesting and to the point. I wanted to talk about
Papercraft and the functional style in Ruby, but without falling into the trap
of discussing all of the theoretical stuff around functional programming. I
mean, there's already a lot of that on YouTube, and I also find it kind of
tedious. I really prefer to stick to practical stuff, like what can we learn
from functional programming that makes us into better programmers.

So, when the day came I took the train to Paris, had a couple hours to burn so I
just sat in a café and rehearsed the text over and over. I thought I had it. But
when the time finally came to give the talk later that evening, something
happened, something that hasn't happened to me in a while - I had a panic on
stage. Well, I didn't start screaming or anything, but as I started talking I
suddenly felt like I had no air. I tried to calm myself and breathe but it was
like my body was tightening into a coil, I felt like I was drowning. Somehow, I
pulled through, I just went through the text and the slides as best I could, and
as I got to the end, I had calmed down enough to be able to be present and
responsive to the people in the audience. There were some questions from the
audience, and I was calm enough to be able to answer, but inside I just felt
crushed and beaten.

This, I mean stage fright, is something I've been struggling with over the
years, but after the positive experience of my lightning talk at
[Euruko](/articles/2025-09-23-euruko) I thought I finally made some progress on
this front. This experience was so discouraging that afterwards I felt
completely empty and without energy. I still want to do more public speaking,
and I think I have interesting stuff to share, but every such negative
experience just adds to my predicament. Well, I guess I still have more work to
do, you win some, you lose some...

By the way, the Euruko talks are now available on YouTube. You can find my
Papercraft lightning talk
[here](https://www.youtube.com/watch?v=sgAysDO3mwU&t=1800s). The slides for the
Paris.rb talk are [here](https://papercraft.noteflakes.com/talks/2025-11).

## UringMachine Grant Work

I've [written before](/articles/2025-06-28-introducing-uringmachine) about
[UringMachine](https://github.com/digital-fabric/uringmachine), a Ruby gem
low-level I/O using io_uring. I'm pleased to announce that I'm the recipient of
a [grant](https://www.ruby.or.jp/en/news/20251030) for working on UringMachine
from the Ruby Association in Japan.

In this project, I'll work on three things:

- Developing a `FiberScheduler` implementation for UringMachine, in order to be
  able to allow its use in any fiber-based Ruby application.
- Bringing SSL/TLS capabilities to UringMachine, in order to allow building
  high-performance clients and servers using encrypted connections.
- Bringing more io_uring features to UringMachine, such as `writev`, `splice`, `fsync`, `fadvise` etc.

I'll also take the time to work on documentation, benchmarks, and
correctness of the implementation.

I'll write here regularly about my progress. The grant also requires me publish
a progress report around December, and then a final report on my work in March.

## A New Client

I've just received a new commission for creating a blog website. The client is a
person I love deeply - my daughter Noa. She has some very specific requirements
regarding the design, functionality, and privacy concerns of the blog, so for
me this is a challenge to see how far I can take my [personal web
framework](https://github.com/digital-fabric/syntropy), and how far I can push
the new ideas and techniques I've been developing for my work.

As I develop and discover solutions for the different problems this new project
presents, I'll try to generalize them and fold them into Syntropy, so I'll be
able to use them for other projects as well.