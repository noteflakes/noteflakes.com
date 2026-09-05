---
title: "Beyond ORMs"
layout: article
---

I've always been interested in the design of ORMs - I wanted to know how they
work, what the different approaches are, and how they can be used. I tried a
bunch of different ones, I even created
[one](https://github.com/jeremyevans/sequel/). But in the last few years I've
been slowly gravitating toward working more directly with databases - issuing
queries using plain SQL, processing raw data coming from the database, or
building custom low-level abstractions for working with relational databases.
This evolution in the way my code talks to databases is the reason I created
[Extralite](https://github.com/digital-fabric/extralite), a Ruby gem for working
with SQLite databases.

Why do I prefer direct interaction with the database instead of using an ORM?
For any developer well-versed in SQL the limitations of ORMs should be obvious -
there's no support for features such as window functions, common table
expressions (CTEs), or even the `RETURNING` clause; the ORM layer itself is a
substantial dependency (the ActiveRecord codebase is about ~43KLoC), it imposes
a performance cost in terms of memory and CPU time; and its defining feature,
the mapping of rows to objects, is an anti-pattern that has been described as
"[the Vietnam of computer
science](https://blog.codinghorror.com/object-relational-mapping-is-the-vietnam-of-computer-science/)".

Now, I'm well aware of the fact that ActiveRecord is by far the most popular way
to talk to a database in the Ruby/Rails community, and has greatly influenced
many other ORMs for Ruby and other languages. But to me ActiveRecord has always
felt wrong. The longer I work building web apps and platforms, the clearer it is
to me. ActiveRecord provides the wrong abstraction for relational data.
ActiveRecord concentrates on the single record, the idea that each record is an
entity in and of itself. In reality, however, a normalized database will contain
many tables with ancillary data, such as tags or labels, which does not need to
be treated as entities. There's time series data and event logs. Nowadays
relational databases are even used as key-value stores and job queues. For these
types of data, we're frequently interested in record *sets* rather than
individual records, and we don't really need the entity abstraction. For those
uses, ActiveRecord seems clumsy and wasteful.

Since ActiveRecord's API revolves around the idea of a separate object for each
row, descended from `ActiveRecord::Base`, with its hundreds of instance and
class methods, programmers may get the idea that they're actually dealing with
discrete objects, and not entries in a record set. With ActiveRecord, a novice
programmer might want to delete or update multiple records using `#each`, e.g.:

```ruby
def make_bracelet(material)
  beads = Bead.where(material:).all
  bracelet = Bracelet.new(beads)
  beads.each(&:delete) # <== a separate DELETE query for each bead
  bracelet
end
```

In the example above, we issue one `SELECT` query to get the beads we're
interested in, and then for each post we'll issue a `DELETE` query, so we got a
`N+1` situation. Of course, a simple solution would be to call `delete_all`
instead of looping over the beads we read:

```ruby
def make_bracelet(material)
  beads = Bead.where(material:).all
  bracelet = Bracelet.new(beads)
  Bead.where(material:).delete_all
  bracelet
end
```

So now we're down to two queries, a `SELECT` query and a `DELETE` query, both
of which have the same `WHERE` clause:

```sql
select * from beads where material = ?;
delete from beads where material = ?;
```

One problem with this is that we're not guaranteed that those two queries will
touch the same records, unless we run the two queries inside a transaction. A
second problem is that we're still doing two round-trips to the database. Can't
we both read and delete records in a single query? Yes we can, at least in
databases such as PostgreSQL and SQLite, using the `RETURNING` clause:

```sql
delete from beads where material = ? returning *;
```

Running this query will delete the relevant records, and return their content.
As far as I could tell, there's no API for this kind of query in ActiveRecord.
But all we need is a just a way to run a plain SQL query, which should be easy
using Extralite:

```ruby
def make_bracelet(material)
  beads = @db.query <<~SQL
    delete from beads where material = ? returning *
  SQL
  Bracelet.new(beads)
end
```

What we've achieved here is to reduce the interaction with the database to a
single query that both deletes the relevant rows and returns their content. Yes,
this means that we express queries in plain SQL, which might give you pause, but
bear with me, I'm going somewhere with this.

## The DSL Trap

One of the main selling points of ActiveRecord and ORMs in general is the
convenience of a DSL: no need to write SQL, just use our *magical* DSL to
construct any query you want. So in fact what happens is that you get a terrific
general-purpose API with literally hundreds of instance and class methods, that
allows you to dynamically build queries however you wish. But do we really need
all those hundreds of methods?

Something I've observed in practically every web app codebase I ever looked at,
is that, except in very rare cases, the number of *different* queries a given
app will make is finite, and in fact relatively small. All those CRUD apps -
*written by CRUD monkeys 😉* - they basically just issue a few different types of
queries. For example, a simple blog app might perform the following different
queries:

```ruby
Post.Create(title: 'foo', body: 'bar')            # create
post = Post.find(42)                              # read
post.save                                         # update
post.delete                                       # delete
Post.order_by(:stamp).all                         # list
Post.where(category: 'baz').order_by(:stamp).all  # list by category
```

Your app might want to bring in some associations, it might want to be able to
filter and sort posts in different ways, so it's going have to make a few other
queries, but their number would average, I'd guess a rough estimate, maybe a
dozen different queries per table. That, unless you're building a full-featured
*visual query builder* app!

So I think the question that should be asked is: if we only need to make a few
dozen different queries, why should we use a DSL in the first place? Do we
really need all of ActiveRecord's magic and expressivness? Why not just express
those queries directly in SQL? Compared to the amount of Ruby code in your app,
the amount of SQL you'll have to write is a drop in the bucket!

Now, one could argue that the biggest advantage of using ActiveRecord over
writing plain SQL queries would be the lack of boilerplate and all the features
you get for free, of which associations are perhaps the most important. Then
again, in my opinion those abstractions have a way of crumbling under their own
weight the moment you try to do something a bit more advanced or esoteric, such
as incorporating non-entity data in your queries, or using window functions for
example.

I think interacting with relational databases without having a basic grasp of
SQL is not a good idea. Yes, vibe-coding has taken our profession by storm, and
lots of people apparently think that the code doesn't matter anymore and that we
shouldn't even look at it, and that we're now all *prompt monkeys* and we should
all just spend our day paying lots of money to Anthropic, watch our "quotas",
come up with creative ways to economize tokens (what a silly notion!) and
building all those groovy exotic hyper-complex loops and harnesses and "skills"
and `AGENTS.md` files and all that *nonsense*, instead of, you know, just
writing normal code that works.

It is the present author's opinion that understanding your code still matters,
understanding what your database is doing still matters, performance still
matters, and having at least a modicum of frugality in using compute resources
still matters (actually it matters even more considering our present
environmental challenges!)

Besides, I find it interesting that on one hand so much effort is being expended
on making the Ruby runtime faster, yet developers who use Ruby on Rails seem to
have such a cavalier, almost ignorant, attitude to performance: "who cares,
compute is an infinite resource, the agent will take care of it, we'll just tell
it to make the code faster". And indeed, who can fault them? As long as AI
platform prices do not reflect the true cost of AI compute, why should people
who vibe-code care at all about the performance of their own code (which they
haven't looked at!), why should they care about getting the most out of their
compute infrastructure? In that sense, the absolutely amazing work done by a few
very talented developers on making Ruby itself faster, is a sisyphean task,
taking into account the ridiculous amount of unstoppable slop being added
daily to actual Ruby on Rails apps. But I digress.

## Rethinking the M in MVC

It has long been accepted that the M in MVC is supposed to be some kind of an
ORM, a layer whose main responsibility is mapping table rows to entity objects,
and providing an expressive API for getting a hold of such objects and
manipulating them. But maybe instead of interacting with the database using a
general-purpose query builder, we can come up with our own *custom made API* for
interacting with the database. Let's retake the example of a simple blog app,
and imagine we had an interface that's custom-made for dealing with posts:

```ruby
posts = PostsStore.new(db)
id = posts.create(title: 'foo', body: 'bar')  # create
post = posts.by_id(id)                        # id
posts.update_by_id(id, title: 'FOO')          # update
posts.delete_by_id(id)                        # delete
posts.all                                     # list
posts.all_by_category(category: 'baz')        # list by category
```

Those are the same six queries as before, but the methods that return rows do so
using plain Ruby hashes instead of custom objects. From the point of view of the
app, this is just a change of interface, we've essentially created a bespoke API
for reading and manipulating posts for our blog app. Just like with
ActiveRecord, the whole database layer is abstracted away in a set of methods,
the controller/business logic code doesn't need to use a `Post` class with its
deep, chainable API, it just calls methods on an interface.

The most important change, hoewever, is that whenever we deal with posts, we
cannot just invent new queries, we have to use the ones that exist, or add new
ones to the `PostsStore` class. The implementation of `PostsStore` is quite
simple:

```ruby
class PostsStore
  def initialize(db)
    @db = db
  end

  def create(title:, body:)
    @db.query_splat <<~SQL, title, body
      insert into posts (title, body)
      values (?, ?)
      returning id
    SQL
  end

  def by_id(id)
    @db.query_single_row <<~SQL, id
      select id, title, body
      from posts
      where id = ?
    SQL
  end

  ...

  def all
    @db.query <<~SQL
      select id, title, body, stamp
      from posts
      order by stamp desc
    SQL
  end
end
```

Here we're taking advantage of one of Extralite's defining features - the
ability to extract data in however form you want, be it a single value, a single
row, or a set of rows. Extralite also has some more advanced features, as I'll
show below.

Look at all the things we're not doing: there are no entity objects, the data we
want is returned from the database in the form we need, in plain Ruby hashes,
Everything is explicit and easily understandable - the queries, the parameters,
the columns. We've cut down substantially on the number of allocations we make.
And of course, this kind of code can be easily scaffolded (for CRUD usage) or
even generated by your favorite slop agent if you're so disposed.

Also, look at how we removed all the unnecessary abstractions: there's no entity
classes, there's no DSL driving the building of queries. We're just talking to
the database directly, with the help of Extralite, and we provide a convenient
API that abstracts the database layer.

## The Model Layer is an API

This design might seem baffling at first - where's the ability to create queries
on the fly as the app is developed? Where is the interaction with entities?
Where do I put my business logic? The answer to all these questions is: the
store class. The store class encapsulates everything that has to do with a
certain kind of data. The store class should function as *the* interface for
interacting with posts. Whatever you need to do with posts, it should be in the
`PostsStore` class. For example, if you need to read posts with associations,
just add a method that performs the right query and returns the data with the
associations included. Here too, Extralite can help us, since it can [transform
projections of joined
rows](https://github.com/digital-fabric/extralite/#structured-transforms),
effectively converting a result set into an object graph:

```ruby
class PostsStore
  POSTS_WITH_AUTHORS = Extralite::Transform do
    {
      id:       integer.identity, # posts.id
      title:    text,             # posts.title
      body:     text,             # posts.body
      stamp:    integer,          # posts.stamp
      author:   {
        id:     integer.identity, # authors.id
        name:   text              # authors.name
      }]
    }
  end
  
  def all_with_authors
    @db.query POSTS_WITH_AUTHORS, <<~SQL
      select posts.id, posts.title, posts.body, posts.stamp,
             authors.id, authors.name
      from postss
      join authors on authors.id = posts.author_id
      order by posts.stamp desc
    SQL
  end
end
```

Now, you might say: all this code for something I could've gotten for free with
ActiveRecord! Yes, it requires some SQL and support code to be written in order
to implement this, but from the point of view of your app, the API is just as
simple as before, and the data you get out of the store interface contains
everything you need, only it's expressed using plain Ruby hashes:

```ruby
# here's how a view might look like, using Papercraft:
POSTS_VIEW = ->(posts:) {
  div(id: 'posts') {
    posts.each { |p|
      div(class: 'item') {
        h3 p[:title]
        h4 p[:author][:name]
        markdown snippet(p[:body])
      }
    
  }
}

# Here's how a controller might look like, Using Syntropy:
def call(req)
  posts = @posts_store.all_with_authors
  html = LAYOUT.render(posts:, &POSTS_VIEW)
  req.render_html(html)
end
```

Frankly, how is this any more difficult than using ActiveRecord? In addition,
instead of deep, chained method calls such as `Post.where(...).order_by(...)`
spread all over our app's codebase, we have created a special-purpose interface
custom made for our specific kind of entity (blog posts) that deals with
everything we want to do with them, and abstracts them behind regular method
calls, no magic involved.

Another detail I'd like to address is the fact the posts store is implemented as
a class, when in fact it is used more like a singleton. The reason I'm
implementing it as a class is to be able to inject a database connection into
the store object. You can do it in many other ways if you wish, depending on
your needs. For example you might want to pass in a connection pool instead of a
connection, or just implement the interface as a global singleton module. It all
basically comes down to the same idea: the model layer as an interface, not as a
DSL driving classes of entity objects.

The store abstraction (it's really just an interface) can also be used to
interact with non-entity data, such as time series data, auxiliary data, a key
value store, a job queue etc. A store doesn't even need to correspond to a
single table. Since its building blocks are SQL queries, you can access any
number of tables, using *all* available SQL features, in order to read and
manipulate the relevant data.

## Passing Interfaces Around

One aspect of this design that merits further discussion is the idea of passing
interfaces as parameters to method calls. In Ruby, we don't really talk about
interfaces, we talk about discrete objects with which we interact directly. An
interface is also an object, but it doesn't encapsulate data (though it may have
some state), it encapsulates functionality. It *is* in fact, a container of
methods.

I've been using the interface pattern for quite a while. In
[UringMachine](https://github.com/digital-fabric/uringmachine) for example, I/O
is performed using an interface, an instance of `UringMachine` or `UM` for
short:

```ruby
require 'uringmachine'

machine = UM.new
machine.write(UM::STDOUT_FILENO, "hello, world!")
machine.open('foo.txt', UM::O_RDONLY) do |fd|
  buf = +''
  size = machine.read(fd, buf, 8192)
  machine.write(UM::STDOUT_FILENO, buf)
end
```

In essence, all I/O operations are done through this interface, which means that
you need to have a reference to the interface anywhere you do I/O. This design
is not unique to UringMachine. Most notably, the Zig programming language now
implements I/O as an interface, which is passed around as a parameter (this, in
addition to an allocator interface). While this means that you need to pass the
interface object around to different parts of your app, you can use various
techniques to simplify working with the interface. One way is to use dependency
injection. We saw an example of this above, where we inject a database instance
into a `PostsStore` instance. The same can be applied to UringMachine, where we
pass the machine instance to an object that abstracts an HTTP connection:

```ruby
class HTTPConnection
  def initialize(machine, fd, &handler)
    @fd = fd
    @machine = machine
    @handler = handler
  end

  def respond_empty(status = 200)
    @machine.write(@fd, "HTTP/1.1 #{status}\r\nContent-Length: 0\r\n\r\n")
  end
end
```

A related approach is by using closures, which is especially useful when dealing
with callables:

```ruby
def make_posts_handler(posts_store)
  ->(req) {
    posts = posts_store.all
    req.respond_html(render_posts(posts))
  }
end

app.start(&make_posts_handler(@posts_store))
```

In fact, I recently read a blog post that demonstrates this technique, and shows
[how it can be used in Go for building HTTP
servers](https://blainsmith.com/articles/how-i-write-http-servers/).

One important consequence of using this kind of interface object, is that it
encourages you to build your app in a more responsible way. For example, you
might be tempted, unless you knew better, to read or manipulate posts somewhere
in the bowels of a view template. Well, with this kind of design, you can't,
unless the template code has gotten a hold of a `PostsStore` instance, which is
a bad idea and should be *verboten*. Thus, you can make sure that any part of
your code that doesn't hold a reference to a `PostsStore` interface can't touch
the database. This also facilitates testing, since you can easily mock a
`PostsStore` interface object.

## Taking Advantage of Prepared Statements

But let's get back to ORMs. Another missing feature in ORMs is the ability to
use prepared statements. Prepared statements, in SQLite and I believe also in
PostgreSQL are queries that have been prepared in advance and can be executed
again and again by the application, without the database having to parse the
query again and again each time it is executed. Prepared statements are
ephemeral - they exist only for the duration of the database connection. In
SQLite, those are simply normal queries
([statements](https://sqlite.org/c3ref/stmt.html) in SQLite tech lingo) that are
kept in memory in order to be reused, instead of being discarded directly after
being executed.

Since we're dealing with (in most cases) a finite number of different queries,
why should the database have to parse over and over again the same queries? We
can use prepared statements for that. While Extralite does have an
`Extralite::Query` class that implements prepared statements (or queries), I've
been working recently on automatic caching of statements at the database level,
such that any query that's issued with parameters is stored in a cache, and
automatically reused whenever the same SQL is given to `Database#query`.

The code is not yet released (hopefully it'll be ready by the end of the month),
and I still haven't done any benchmarking to see how it affects performance.
Using this feature you will get slightly higher memory usage (each prepared
query consumes a few KBs of RAM), but you'll reduce CPU time, and you'll also
reduce allocations.

I'm excited to see where this goes, and how far we can push the idea of getting
the most out of SQLite databases. Ruby is hella fast nowadays, and it's only
getting faster and better. now it's our turn to get rid of wasteful and unneeded
abstractions, and engage again in writing faster, leaner, better software.
