---
layout: default
---

## 0-01 talk title (30s)

Bonjour à toutes et à tous. Je m'appele Sharon et ce soir je vais vous
parler de Papercraft et du style fonctionnel en Ruby.

## 0-02 Noteflakes (60s)

D'abord, quelques mots sur moi: Je suis developpeur de logiciel indépendant. Ma
boite s'appelle Noteflakes. Je travaille principalement dans le domaine de la
télégestion et la surveillance de processus industriels, surtout dans
l'infrastructure: distribution d'eau potable, stations de pompage, traitment des
eaux usées, distribution de gaz naturel, etc. Quand on me demande ce que je
fais, je dis que je suis plombier, je fais de la plomberie numérique.

J'ai pas mal d'expérience avec Ruby, mais pas que. Et je fais un peu de tout,
backend, frontend, sysops, maintenance, sécurité, etc.

### 0-03 List of my OSS projects (60s)

Je suis aussi auteur de plusieures gemmes pour Ruby, la plus connue serait
Sequel, que j'ai crée il y a 18 ans je crois. Je developpe mes propres outils
pour mon boulot, mais aussi pour mon plaisir.

Voilà qui je suis, et maintenant, avec votre permission, pour la partie
technique je vais passer en anglais...

## 1-01 What is Papercraft? (90s)

So I will start by talking about Papercraft, which is one of my newer gems, this
is something I've been working on intensively for the last few months, since I
needed to build a few websites. In my software development work, I've been
slowly gravitating in the last few years towards a style of programming that is
inspired by the functional approach.

So Papercraft is about expressing HTML templates as pure functions, in the form
of lambdas, as well call them in Ruby. This *functional* approach makes it easier
to compose and reuse templates, as we shall see in a few moments.

## 1-02 Papercraft vs ERB (70s)

So why Papercraft? Why not ERB? Well, personally I find ERB quite frustrating.
It's not pleasant to write or to read, and it makes it easy to generate invalid
HTML, and there's all this switching all the time between two kinds of syntax.

With Papercraft, on the other hand, you stay in the zone. You just write Ruby,
there's no boilerplate, there's also no state, it's just pure functions, and
*because* arguments are explicit, you can easily follow the flow of data through
your templates.

## 1-03 Layouts (90s)

Let's look at how layouts are done in Papercraft. We start with a default
layout, which renders the html, head and body tags (with the page title), and
then we call render_children, which tells Papercraft to render whatever block is
passed to the template. To generate the HTML we call Papercraft.html with the
default layout template, and we pass a block that will be rendered by the
render_children method we put in the layout.

There's also the possibility to create a derived layout using Papercraft.apply.
What this does is it takes the given template, applies any arguments or block
you provide, and returns a derived *applied* template. So here we define an
article layout, which is derived from the default layout by *applying* a block
that renders an article tag, and then the article content. Finally we render the
page by calling Papercraft.html, passing it the derived template, and the actual
article data.

## 1-04 Components (60s)

Another way to compose templates is by defining components (which by convention
are defined as constants). Here, we define a table component, which takes an
array of columns and an array of rows, and renders a table tag with all its
inner elements, passing each piece of data to the relevant HTML tag. Basically,
you get a completely self-contained pure function template that is reusable in
any kind of context or situation.

To use it, we make a call in our template to Table (with a capital T), and we
pass it the relevant arguments. Since it's all just lambdas (or functions), it's
easy to compose and reuse components with arbitrary complexity.

## 1-05 The functional style (150s)

So Papercraft is really about embracing the functional style in Ruby, and
expressing HTML templates as functions. What's so special about functions, or
lambdas as we call them in Ruby? How is this different than just using methods?

Well, basically you can do everything you want inside of a lambda, just like in
a method. You're not obliged to make it pure and *functiony*. You can take
arguments, you can a block, you even have access to self, and to instance
variables! The difference is not what happens on the inside of a lambda. The
different is on the outside!

A lambda is an expression, it's a value! You basically take a bunch of code and
package it in a value, that you can assign to a variable, you can pass it as an
argument, or use it as a return value from some other lambda or method.

And I think this is a key insight of functional programming. It makes you think
about code as data. I think this is one of the most important things functional
programming has to teach us.

## 1-06 Papercraft DSL implementation

The notion of code as data is at the heart of how Papercraft works internally.
You see, normally, a DSL like this would work by actually running the DSL code
using `instance_eval`. This is also called the builder pattern. But this
is not how Papercraft does it.

So the code on the left is about developer happiness, right? It makes you happy.
But ideally we'd want to do something more like the code on the right, if we
care about performance, or machine happiness. So with Papercraft I wanted to
find a way to achieve both developer happiness and machine happiness.

So, suppose we want to somehow transform the code on the left into the code on
the right. How do we do this? We start by converting the DSL code on into data,
data that we can somehow transform. So, how do you convert code into data? And
what data structure can you use to represent code? Anyone?

## 1-07 AST

An AST - an Abstract Syntax Tree. This is the AST for the same template as
before. In fact, Papercraft uses the same parser Ruby itself uses, called Prism.
And as you can see, we get very detailed information.

So, the first thing we do is to find the source code of the lambda, to be brief,
this is done by using the source_location method, which gives us the filename
and line number where the lambda is defined. We then parse the source file using
Prism, and look for a LambdaNode at the correct location.

So what can we do with this AST? We can identify all the places where an HTML
tag is declared. Since this is a DSL, we know that HTML tags are expressed as
method calls without a receiver. 

## 1-08 Translator

So, Papercraft goes over the entire AST and finds all of the `CallNode`s where
`receiver` is nil. It then mutates the AST such that each of those `CallNode`s
is converted into a custom `TagNode`, which will let our compiler know it needs
to generate HTML.

## 1-09 Compiler stage

The next stage is for the Papercraft compiler to take the mutated AST, and
convert it back to source code. Each time the compiler hits a `TagNode`, it
emits a piece of HTML. And finally all those pieces of HTML will be integrated
in chunks into the generated source code, in the form of method calls to stuff
those strings into a buffer.

## 1-10 Result: everyone is happy

The final result is then `eval`'d and we get back a lambda with the optimized
code. And thus, everyone is happy! You, the developper, are happy, and your
machine is also happy, because it needs to do much less work to achieve the same
result.

## 1-11 code as data: the future of DSLs

So, when we look at code as data, we also start reading code differently. We can
look at the lambda on the left in terms of not what it does, but in terms of
what is its return value. In this case: a piece of HTML.

What does this mean for DSLs in Ruby? If we start looking at code in this way,
we can start designing and implementing DSL APIs differently. We can introduce
new techniques for metaprogramming - for generating code at runtime. We can
allow DSL patterns that are difficult or too slow to implement using
`instance_eval`. We can perform introspection and transformation of code at
runtime.

## 1-12 File-based routing

There's one more thing I'd like to show you before concluding. I'm currently
working on a web framework called Syntropy. It's still not officially released
but you can look for it on GitHub. It's currently driving a bunch of my
websites, including the slides you're currently seeing. Syntropy uses file-based
routing, which means that the directory structure of your website source code is
used as the URL structure.

What Syntropy does is on startup it traverses your app's directory structure,
collects all the files, in a tree structure that mirrors the directory structure
and holds all the route information for each file.

This tree structure is then used for generating an optimized router function (or
lambda) that parses the URL path and immediately returns the correct route from
flat route maps, according to the underlying tree structure, without having to
traverse the tree on each invocation. So you get optimized code that is custom
generated for your specific circumstances.

We're all looking to improve the quality of our code, to make it easier to test,
easier to maintain, easier to extend. And in that regard, the functional style
has many advantages. Pure functions are especially revealing, because they
demand a discipline that turns us into better programmers.

Personally, now when I'm faced with a new problem, I'm always thinking, can this
be solved with a functional approach, can this be expressed with pure functions?
And when you start thinking that way, you start also thinking about what data
structures you're using to represent a problem. What transformations you can do
with the data. So I think there's still a lot more to discover and learn from
embracing the functional style in Ruby.

## 1-13 Summary

So to sum up, Papercraft is innovative in two ways: first, HTML templates
expressed as pure functions, and second, the automatic compilation of those
templates into an optimized form, such that you get not only developer happiness
but also machine happiness.

There are some future directions I'm currently exploring for Papercraft, such as
inlining of components, template debugging tools, introspection, selective
rendering etc.

I'm also looking into creating a set of comprehensive tools for generating code
at runtime, and for manipulating ASTs, because I really believe this is the
future of metaprogramming in Ruby.

I hope you found this talk interesting, and I thank you for listening. (Are we
going to take any questions?)
