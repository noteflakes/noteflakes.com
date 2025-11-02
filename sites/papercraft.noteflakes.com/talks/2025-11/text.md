### 0-01 talk title (30s)

Bonjour à toutes et à tous. Je m'appele Sharon et ce soir je vais vous
parler un peu de Papercraft et du style fonctionnel en Ruby.

## 0-02 Noteflakes (60s)

D'abord, quelques mots sur moi, je suis Israelien à l'origine. Je vis avec ma
femme et mes enfants en France depuis 12 ans. On habite en Bourgogne, dans le
Charolais.

Je suis developpeur de logiciel indépendant, et je travaille principalement dans
le domaine de la télégestion et surveillance de processus industriels, surtout
dans l'infrastructure: distribution d'eau potable, stations de pompage,
traitment des eaux usées, distribution de gaz naturel, electricité etc. 

Je travaille pour la plupart tout seul, parfois avec un ou deux autres
collaborateurs, et je fais un peu de tout - surtout le backend, mais aussi
frontend, sysops, maintenance, sécurité etc.

### 0-03 List of my OSS projects (60s)

Je suis aussi auteur de plusieures gemmes pour Ruby, la plus connue serait
Sequel, que j'ai crée il y a 18 ans je crois. Je developpe mes propres outils
pour mon boulot, et pour la plûpart je les publie en open-source.

Maintenant, avec votre permission, pour la partie technique je vais passer en
anglais...

(total 2:30)
--------------------------------------------------------------------------------

## 1-01 What is Papercraft? (90s)

Now, I guess all of you know how to generate HTML with ERB templates, and ERB is
pretty cool! But with Papercraft, you don't need to do the mental switch between
writing HTML tags and writing Ruby logic, and you can keep your templates in the
same file right along your controller code. Papercraft also makes it very easy
to compose templates. Creating layouts, partials and components is almost
trivial!

Papercraft is designed for developer happiness, but it does not compromize on
rendering performance, as we shall see, because Papercraft actually compiles
your template source code into an optimized form, and later I'll explain how all
of this works.

## 1-02 Papercraft vs ERB (70s)

So let's compare Papercraft to ERB in terms of how the template source code
looks. To me, one the biggest issues with ERB is that it's not so much fun to
write, and it is definitely not very easy to read. You're mixing two different
kinds of syntax, it is also kind of verbose, and it is error prone.

With Papercraft, on the other hand, you stay in the zone. You just write Ruby,
there's no boilerplate, there's no state (like ivars), it's just pure functions,
and because arguments are explicit, you can easily follow the flow of data
through your templates.

## 1-03 Layouts (90s)

Let's look at how layouts are done in Papercraft. We start with a default
layout, which renders the html, head and body tags (with the page title), and
then we call render_children, which will render whatever block is passed to the
template.

We then define an article layout, which is derived from the default layout using
the apply method, which passes a block that renders an article tag, an h1 tag
with the article title, and then renders the markdown content of the article.

Finally we call render on the article layout, passing it the actual article
data.

## 1-04 Components (60s)

Another way to compose templates is by defining components (which by convention
are defined as constants). Here, we define a table component, which takes an
array of columns and an array of rows, and renders a table tag with all its
inner elements, passing each piece of data to the relevant HTML tag. Basically,
you get a completely self-contained pure function template that is reusable.

To use it, we make a call in our template to Table (with a capital T), and we
pass it the relevant arguments. Since it's all just lambdas (or functions), it's
easy to compose and reuse components with arbitrary complexity.

(total 7:30)

## 1-05 The functional style (150s)

So Papercraft is really about embracing the functional style in Ruby, and
expressing HTML templates as functions. What's so special about functions, or
lambdas as we call them in Ruby? How is this different than a method?

Basically you can do everything you want inside of a almbda, just like in a
method. You're not obliged to make it pure and functional. The difference is not
what happens on the inside of a lambda. The different is on the outside!

You can treat a lambda as a value! You can store it in a variable, you can use
it as an argument, or a return value, from another lambda. You can't do this
with a method!

And I think this is the key insight of functional programming. It makes you
think about code as data. I think this is really what functional programming
teaches us.

(total 10:00)

## 1-06 How the Papercraft DSL works (200s)

This notion of code as data also informs how Papercraft works internally. This
is something I realized after the fact, but the way that the Papercraft DSL
is implemented is in a way a manifestation of this idea.

So doing HTML templates using a Ruby DSL is nothing new. There's a bunch of Ruby
gems that already do this: Markaby, Arbre, Ruby2HTML, Phlex. All of those gems
basically work the same way. This is also called the "builder pattern", where
you take a block of DSL code, and you run it using instance_eval.

But Papercraft does it differently. Like ERB, it takes your template source code
and *compiles* it into an optimized form. So let's examine for a moment how this
is done. How can we take the code on the left, and transform it into the code on
the right?

There are a few different steps we need to go through: first, since we want to
be able to do this at runtime, we need to get the source code of the given
lambda. We then need to parse the source code into an AST (abstract syntax
tree), we then need to do some transformation on the AST, and finally to convert
the mutated AST back into source code. So, getting the source code and parsing
it is pretty easy: we call source_location on the lambda, which gives us the
filename and the line no where the lambda appears in the source, we parse the
source file (using Prism), and look for a LambdaNode that's located at the
relevant line number.

We then need to go over the lambda AST  and detect all the places where HTML
tags are added. How can we tell a tag method call from any other kind of method
call? It's simple, the tag method call doesn't have a receiver, so we're looking
for any CallNode where the receiver is nil.

We then replace the CallNode with a custom TagNode that wraps the CallNode, and
we do this all over the tree. Finally we convert the mutated AST back to source
code, but everytime we hit a TagNode, we emit a piece of HTML, that will be
eventually be emitted into the source code as code that stuffs strings into a
buffer.

So, the act of converting a piece code into an AST is basically converting code
into data. And the reciprocal act of converting an AST into code is the
opposite, we convert data into code. So again, this notion of code as data comes
back to us.

Here we can make an analogy: we all know the equation E = mc2, which means that
energy and mass are two aspects of the same thing. So maybe we can say that code
and data are also two aspects of the same thing and can be converted from one to
the other. I find this equivalency really fascinating.

(total 12:30)

---------------------

So let's talk more about functional programming and what it means to the way we
write our programs. I mentioned pure functions at the beginning of the talk.
Now, a pure function is a function that has two properties: first, it always
gives you the same return value for the same arguments, and second, it does not
have any side effects. This means it cannot make any change to the state of your
application, it cannot write to a file, or to a socket, it cannot output
anything to the screen, etc.

So the first property, the same return value for the same arguments, means that
the function is not influenced by what's going on in the outside world - like
what time it is, or is it raining. It is predictable, it always gives you the
same output for a given input, which means that you can use it in any context,
in any kind of situation. This also means that it is much much easier to test.

(1:10)

The second property of pure functions raises the question: if we can't have any
side effects, how can we do any useful work? If we're not allowed to touch the
database, or the log file, or write to a file, or send emails, how can we do
anything meaningful?

One solution to this is the principle of "functional core / imperative shell".
It means that we write the core of our application, the business logic as we
call it, in a functional style, and we wrap our application logic with a
imperative shell, which talks to the outside world, and then calls into the
functional core.

(1:50)

But if we implement our business logic in a functional core, that is not aware
of the outside world, and is not coupled to any external service, how can we
effect any change to the application state? How can we interact with the users?

Here again, the insight of code as data can help us imagine a way to do just
this. I find that a lot of times we tend to abstract the wrong thing, we
normally concentrate on abstracting the database (with an ORM, for example), or
using dependency injection as a way to prevent our app logic from being coupled
to a an external service.

But maybe instead of abstracting the external world, abstracting our
dependencies so-to-speak, we can abstract our business logic, we can abstract
the interactions and the operations required for our business logic.

If we compare functional programming is to imperative programming, we can say
that functional programming is about describing a computation, while imperative
programming is about prescribing a computation.

So how about we describe our side effects, instead of prescribing them. In other
words, we can replace the code that *performs* the side effects with a
*description* of the side effects. So, instead of using dependency injection to
pass external interfaces to our functional core, and have it interact with them,
we can have our functional core *return* a specification of side effects to be
performed, and have our imperative shell execute those side effects. Again, code
as data.

(4:15)

What are the implications of this? You know, I was listening to a podcast a few
weeks ago. It was an interview with an engineer from Doctolib. They have this
gigantic Ruby on Rails app, and he was talking about the problems they've been
having with testing. They have a very big codebase, with lots of tests, and the
tests are slow. Why are they slow? You can imagine that for each test case
you'll need to start from a blank database (or maybe even multiple databses),
recreate the schema, populate the tables for the scenarios, run your unit tests,
and then verify that the correct records have been inserted, or updated, or
deleted by talking to the database. You'll also need to mock a bunch of other
external concerns, such as a log, or an email service, etc. So, no wonder those
tests take a lot of effort to write, and are slow to run.

So let's think how the "functional core / imperative shell" principle solves
this problem, where side effects are simply part of the return value of your
functional core: there's no database schema to setup, you don't even need a
database connection, you don't need to mock anything, not even your log file.
You can simply test that the functional core produces the correct side effects
by examining the return value of whatever function the test case was invoking.

(6:00)

So this means that your unit tests run really fast, and it can also mean that
you need less of them, because your functional core has a predicatble behaviour.
And this also means that you can write fewer integration tests, where you just
need to verify that whatever side effects the functional core is emitting, are
correctly executed by the imperative shell.

---------------------------------------------

So, in conclusion, what does all this mean for us Ruby developers? I believe
that functional programming has a lot to teach us. I believe embracing the
functional style of programming can help us evolve towards writing software that
is more dependable, more testable, with less lines of code, with less bugs,
maybe even with better performance characteristics. I think this key insight of
*code as data* can lead to a generation of new tools, like Papercraft.

Personally I can say that with Papercraft I'm only starting to scratch the
surface of what is possible when you embrace the functional style, because I
find this really inspiring. And I hope that ideas I've explored in this talk
will inspire you too. Thank you!
