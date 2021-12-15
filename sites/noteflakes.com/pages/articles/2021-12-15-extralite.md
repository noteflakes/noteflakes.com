---
title: Extralite - a new Ruby gem for working with SQLite databases
date: 2021-12-15
layout: article
---

In the last year I've been working a lot with [SQLite](https://sqlite.org/)
databases. I started by using the popular `sqlite3` Ruby gem, but quickly
noticed that for *my usage* there were a few things missing in the gem's
[API](https://www.rubydoc.info/gems/sqlite3/). Being a tinkerer, and having had
some experience writing [C-extensions](https://digital-fabric/polyphony), I had
a look at the SQLite C API and decided to try to write my own Ruby bindings for
SQLite. Thus Extralite was born.

[Extralite](https://github.com/digital-fabric/extralite) is an extra-lightweight
(less than 460 lines of C-code) SQLite3 wrapper for Ruby. It provides a single
class with a [minimal set of methods] for interacting with an SQLite3 database.
Extralite provides the following improvements over the `sqlite3` gem:

- Improved concurrency for multithreaded apps: the Ruby GVL is released while
  preparing SQL statements and while iterating over results.
- Super fast - up to 13x faster than `sqlite3`.
- Automatically execute SQL strings containing multiple semicolon-separated
  queries (handy for creating/modifying schemas).
- Access data in a variety of ways: rows as hashes, rows as arrays, single row,
  single column, single value.

## Concurrency

One of the most important limitations of the sqlite3-ruby gem is that it doesn't
release the GVL while running queries and fetching rows from the database. This
means that if any query takes a significant amount of time to execute, other
threads will also be blocked while the query is running.

There has been [some
discussion](https://github.com/sparklemotion/sqlite3-ruby/issues/287) on the
sqlite3-ruby repository as to why this is. Basically, since developers can
define their own SQLite functions, aggregates and collations using Ruby, the gem
needs to hold on to the GVL while running queries, since those might call back
into Ruby code.

Extralite does release the GVL when running queries, which makes it much more
friendly to multithreaded code. While Extralite is busy fetching a row, other
threads can continue running. If your program has multiple threads accessing
SQLite databases at the same time, you'll get much better usage out of your
multicore machine.

## Performance

Preliminary benchmarks show Extralite to be significantly faster than
sqlite3-ruby. The
[benchmark](https://github.com/digital-fabric/extralite/blob/main/test/perf.rb)
included in the Extralite repository creates a database with varying number of
rows, then meausres the time it takes for sqlite3-ruby and Extralite to fetch
those rows. The performance advantage becomes more pronounced as the number of
rows is increased:

|Row count|sqlite3-ruby|Extralite|Relative|
|-:|-:|-:|-:|
|10|56.48K rows/s|91.52K rows/s|__1.62x__|
|1K|256.3K rows/s|1758K rows/s|__6.87x__|
|100K|176.5K rows/s|2323.6K rows/s|__13.17x__|

These results surprised me quite a bit, since Extralite *does* release the GVL
on each fetched row, but I guess this is more than made up for by the fact that
Extralite makes a minimum of allocations and offers a significantly smaller API
surface area, compared with sqlite3-ruby.

## Other features

Extralite provides a variety of ways to get query results: rows as hashes, rows
as arrays, a single column, a single row, or a single value. While sqlite3-ruby
has most of these (except for iterating over a single column), you need to set a
mode (`SQLite3::Database#results_as_hash`) if you want to fetch rows as hashes.

Another important feature of Extralite is that it automatically executes SQL
strings containing multiple SQL statements (separated with a semicolon.) In
sqlite3-ruby you need to use a separate API (`#execute_batch`) in order to do
that.

Other features, such as binding indexed and named parameters, getting the last
inserted rowid, getting the number of changes made in the last query or loading
extensions, are available in both gems.

## What's missing

Extralite is notably missing the ability to define custom functions, aggregates
and collations using Ruby. If you rely on that feature, you'll need to use
sqlite3-ruby.

## Usage with ORMs

Extralite includes an adapter for
[Sequel](https://github.com/jeremyevans/sequel). If you wish to switch from
sqlite3-ruby to Extralite, you can just add `extralite` to your `Gemfile`, and
then change your database URLs to use the `extralite` schema instead of
`sqlite`:

```ruby
DB = Sequel.connect('extralite:my.db')
```

What about ActiveRecord? Well, I tried, but after spending a few hours looking
at the ActiveRecord SQLite adapter code and trying to make sense out of that,
all I got was cryptic error messages. I finally decided to abandon the effort.
If you have experience writing ActiveRecord database adapters, I'll greatly
appreciate your contribution. Let me know on the [Extralite
repository](https://github.com/digital-fabric/extralite).

## Future directions

Extralite is pretty much feature-complete as far as I'm concerned, apart from
missing an ActiveRecord adapter. I'm currently thinking about how to adapt the
different abstractions I came up with while working with SQLite databases, but
those will be published in a separate project.

In the meanwhile, if you have suggestions for improving Extralite, or wish to
contribute, please let me know. I'll gladly accept issues and PRs! The
documentation for the Extralite gem can be found
[here](https://www.rubydoc.info/gems/extralite).