---
title: "Real-world Concurrency with Ruby and Polyphony: a Telnet Chat App"
date: 2021-11-13
layout: article
---

Recently there has been a lot of renewed interest in
[fibers](https://rubyapi.org/3.0/o/fiber) as the building blocks for writing
concurrent Ruby apps. Most of the articles written lately (my own included) have
tried to explain what are fibers, how they can be used for writing concurrent
apps, and how fiber scheduling works. While this obviously is great, I feel
there's also a need for developers to get a feel for how a real-world
fiber-based app looks, and how writing such an app differs from using, say,
[EventMachine](https://github.com/eventmachine/eventmachine/) or some other Ruby
library providing a different concurrency model.

In this article I'll walk you through implementing a bare-bones Telnet chat app
using [Polyphony](https://github.com/digital-fabric/polyphony). Along the way,
I'll demonstrate how Polyphony lets us write concurrent programs in a natural,
idiomatic style, and show how fiber messaging, one of Polyphony's unique
features, allows us to design a concurrent app as a collection of simple,
autonomous entities, each having a single responsibility.

The source code for the chat app is available as a
[gist](https://gist.github.com/ciconia/9e2ffbc39d75a8b7433ea6df7c5ddea8).

## Designing our chat app

The chat app we're going to implement today will have the following
requirements:

- Telnet-based (that is, using plain text over TCP sockets.)
- Support any number of concurrent users.
- Support any number of rooms.
- Each user can be in a single room at a time.
- Rooms are ephemeral, so no need to keep a history of messages.
- Users are also ephemeral, no need to keep a user's state.
- User actions are: join a room, leave a room, send a message to a room.
- When a user sends a message to a room, all users in the same room get it.
- A user joins or leaves a room by sending `:enter <room>` or `:leave`,
  respectively.

Now that we have our requirements, let's concentrate on the design of our
program: what are the different moving parts and how do they connect? One of the
biggest advantages of using fibers is that, fibers being so cheap to create (in
terms of computer resources,) we can implement any entity in our program as a
fiber. If we take the problem of a chat app, we have rooms, we have users, and
we have TCP connections. As I'll show below, each of these can be modeled as an
independent fiber.

## Fiber messaging

In order for all those different fibers to communicate with each other, we can
use fiber messaging, a feature that is unique to Polyphony, and is greatly
inspired by [message-passing in
Erlang](https://www.erlang.org/doc/getting_started/conc_prog.html#message-passing), which essentially permits
Erlang processes to behave as concurrent
[actors](https://en.wikipedia.org/wiki/Actor_model).

In Polyphony, each fiber has a mailbox, and can receive messages by calling
`Kernel#receive`. A message can be any Ruby object. To send a message to a
fiber, we call `Fiber#send` or `Fiber#<<`. Receiving a message is a blocking
operation, if the fiber's mailbox is empty, the call to `#receive` will block
until a message is sent to the fiber. The call to `#send`, however, is not
blocking (except if the fiber's mailbox is capped and filled to capacity. By
default fiber mailboxes are not capped.)

Here's a simple example to show how fiber messaging works:

```ruby
require 'polyphony'

receiver = Fiber.current
spin do
  sleep 1
  receiver << "hello"
end

puts "Waiting for message..."
message = receive
puts "Got #{message.inspect}"
```

In the above example, we spin up a fiber that will sleep for 1 second, then send
a message to the main fiber, which meanwhile waits for a message to be received.
This apparently simple mechanism for *asynchronous* communication between fibers
has profound implications for how we can structure our concurrent programs.
Since fibers can behave as actors (just like Erlang processes,) they can
basically have the same capabilities as custom Ruby objects. Think about it:
when we call a method on a Ruby object, we basically send it a message. If
fibers can send and receive messages, we can use them instead of plain Ruby
objects. And just like custom Ruby objects which hold state (stored in instance
variables,) fibers can hold state in local variables.

In order to see how a fiber can hold state and receive "method calls", let's
take the simple example of a calculator with a memory. Our calculator can do
arythmetic operations on the last retained value. Here's how we'll implement
such a calculator using a normal Ruby class definition:

```ruby
class Calculator
  def initialize
    @value = 0
  end

  def add(x)
    @value += x
  end

  def mul(x)
    @value *= x
  end
end

calculator = Calculator.new
calculator.add(3) #=> 3
calculator.mul(2) #=> 6
```

Now let's see how we can do the same thing with a fiber:

```ruby
require 'polyphony'

calculator = spin do
  value = 0
  loop do
    peer, op, x = receive
    case op
    when :add
      value += x
      peer << value
    when :mul
      value *= x
      peer << value
    end
  end
end

calculator << [Fiber.current, :add, 3]
receive #=> 3
calculator << [Fiber.current, :mul, 2]
receive #=> 6
```

The calculator fiber loops infinitely, waiting for messages to be received in
its mailbox. Each message, having been destructured, is processed by updating
the state and sending the updated state to the peer fiber which originated the
message. Notice that in the fiber-based version, in order to get the result of
the arythmetic operation, we need to provide the `calculator` fiber with the
current fiber, to which it will send the result of the operation. In effect, our
calculator fiber can be said to be a sort of server: it receives requests,
handles them, and sends back a reply.

This might seem like a a much more complicated way of doing things, but in fact
look at the stuff we don't need to worry about: we don't need to define a custom
class, and our state is safely stored as a local variable and cannot be accessed
or tampered with from the outside. Finally, since our calculator fiber is doing
one thing at a time we are basically guaranteed to not have any race conditions
when making "calls" to our calculator. Compare this to the "normal"
implementation above, which will fail miserably once we try to call methods from
multiple threads at once.

If we want to make the fiber's interface a bit more like what we're used to with
our normal Ruby method calls, we can wrap our calculator fiber implementation
with something akin to Erlang's
[GenServer](https://www.erlang.org/doc/man/gen_server.html) (generic server)
behavior, as [shown in the Polyphony
repository](https://github.com/digital-fabric/polyphony/blob/master/examples/core/erlang-style-genserver.rb).
Our fiber-based calculator would then look something like this:

```ruby
module Calculator
  module_function

  def initial_state
    0
  end

  def add(state, value)
    state += value
    # The first value is the return value, the second is the mutated state. In
    # our case, they are the same.
    [state, state]
  end

  def mul(state, value)
    state *= value
    [state, state]
  end
end

# start server with initial state
calculator = GenServer.start(calculator)
calculator.add(3) #=> 3
calculator.mul(2) #=> 6
```

One important detail to understand about fiber messaging is that like with any
API, the actual messages sent and received between fibers (which, if you recall,
can be any Ruby object) need to be well defined. An abstraction such as the
`GenServer` example shown above, can help with making those interfaces more
convenient to use, but it is in no way obligatory. We can get by explicitly
sending and receiving fiber messages.

Using fibers to encapsulate state - and fiber messaging to communicate between
fibers - has an additional ramification: it guides the developer towards a more
functional style of programming (the example above is a case in point.) You stop
thinking in classes and objects, and think more in terms of methods and message
passing. While Ruby is pretty good at doing both, in the last few years I've
been personally gravitating towards a more functional programming style, and
Polyphony does facilitate moving in that direction.

But let's go back to our chat app. We'd like to implement the different entities
in our program as fibers, and make them interact using fiber messaging. As noted
above, if we want to use fiber messaging, we'll need to have defined the
different messages that are going to be sent between the different fibers, in
other words the different interfaces those fibers will have. Before starting to
write our implementation, let's first define those.

## Defining fiber interfaces

As we said, we have three kinds of entities: Telnet session, user, and room.
Let's figure out the responsibilities of each entity, and how those entities
interact:

- A room has zero or more users in it.
- A user can enter a room, and can leave a room.
- Once a user enters a room, she'll receive any messages broadcast by other
  users in the same room.
- When a Telnet session starts (the client connection is accepted,) a user is
  created.
- When a Telnet session ends (the socket is closed,) the corresponding user
  leaves the room she's currently in, and then terminates.

Let's now define the shape of the different messages our chat entities should be
able to handle. A *room* fiber needs to be able to handle the following events:

- A user entered the room: `[:enter, name, fiber]`
- A user left the room: `[:leave, name, fiber]`
- A user wrote something: `[:message, message]`

A *user* fiber should handle the following events:

- A line was received from the corresponding socket: `[:input, message]`
- A message was broadcast in the user's room: `[:message, message]`

The Telnet session fiber does not need to handle incoming messages, as its job
is only to wait for lines of text to arrive on the socket, and send them to the
corresponding user. The distinction between session and user is important, since
those two entities have different responsibilities. The user fiber implements
the business logic from the point of view of the user, dealing with
notifications coming either from the room or the Telnet session. The Telnet
session deals exclusively with receiving data on the corresponding TCP socket.

Now that we have defined the interactions and messages sent between the
different parts of our app, let's start writing code!

### The Telnet session

We start writing our code with a straightforward implementation of a TCP server:

```ruby
server = spin do
  server_socket = TCPServer.new('0.0.0.0', 1234)
  server_socket.accept_loop do |s|
    spin { handle_session(s) }
  end
end
```

We start by spinning up a server fiber that will run the TCP server. The server
fiber creates a `TCPServer` instance for accepting connections. The
`#accept_loop` method runs an infinite loop, waiting for connections to be
accepted. For each accepted connection, we spin a separate fiber, calling
`#handle_session` with the accepted connection. Let's look at how
`#handle_session` is implemented:

```ruby
def handle_session(socket)
  socket << 'Please enter your name: '
  name = socket.gets.chomp
  socket.puts "Hello, #{name}!"
  user_fiber = spin { run_user(name, socket) }
  while (line = socket.gets.chomp)
    user_fiber << [:input, line]
  end
ensure
  user_fiber << [:close]
end
```

We start by asking the user for their name, then setup a fiber for the user,
calling `#run_user`. Finally, we run a loop waiting for lines to arrive on our
socket, and send each line to the user fiber.

## The user fiber

Our user fiber will run a loop, waiting for and processing incoming messages:

```ruby
def run_user(name, socket)
  current_room = nil
  loop do
    event, message = receive
    case event
    when :close
      break
    when :input
      case message
      when /\:enter\s+(.+)/
        leave_room(current_room, name) if current_room
        current_room = enter_room($1, name)
      when ':leave'
        leave_room(current_room, name) if current_room
      else
        say(current_room, name, message)
      end
    when :message
      socket.puts message
    end
  end
ensure
  leave_room(current_room, name) if current_room
end
```

We destructure incoming messages (received as an Array of the form `[event,
message]`), then take the correct action according to the message received. Here
are the rest of the user's business logic, which consist of sending messages to
the room the user has entered or left:

```ruby
def leave_room(room_fiber, name)
  room_fiber << [:leave, name, Fiber.current]
end

def enter_room(room_name, name)
  room_fiber = find_room(room_name)
  room_fiber << [:enter, name, Fiber.current]
  room_fiber
end

def say(room_fiber, name, message)
  room_fiber << [:say, name, message]
end
```

## The room

Finally, we get to the room entity, which manages a list of users and takes care
of broadcasting messages received from individual users in the room. Let's start
with the `#find_room` method, which is used by users to find the fiber for the
room they want to enter:

```ruby
@room_fibers = {}
@main_fiber = Fiber.current

def find_room(room_name)
  @room_fibers[room_name] ||= @main_fiber.spin { run_room(room_name) }
end
```

Since `#find_room` is called in the context of the user fiber, we need to be
careful about how we spin up the room fiber. We want our room fiber to not be
limited to the lifetime of the user fiber (which will terminate when the user's
Telnet session closes,) and that means we cannot spin it directly from the user
fiber. Instead, we spin it from the main fiber. Notice that the user fiber
itself is spun from the Telnet session fiber, but since the user fiber should
not outlive its Telnet session that is just fine.

(In a future article I'll show a better way to manage fibers by organizing them
into supervision trees, but for the sake of the present discussion the above
solution is good enough).

Lets continue with the room implementation:

```ruby
def run_room(room_name)
  @users = {}
  loop do
    event, *args = receive
    case event
    when :leave
      name, fiber = args
      @users.delete(args[1])
      broadcast(@users.keys, "#{args[0]} has left the room.")
      break if @users.empty?
    when :enter
      @users[args[1]] = true
      broadcast(@users.keys, "#{args[0]} has entered the room.")
    when :say
      broadcast(@users.keys, "#{args[0]}: #{args[1]}")
    end
  end
ensure
  @room_fibers.delete(room_name)
end

def broadcast(fibers, message)
  fibers.each { |f| f << [:message, message] }
end
```

The room fiber is very similar to the user fiber, in that it runs a loop waiting
for events to be received. The different events are processed by updating the
list of users and broadcasting the corresponding messages to all users.

## Tying it all together

Now that we have implemented the different parts of the application, all that's
left is for the main fiber to wait for the server fiber to terminate (which will
never arrive). We do that by calling `Fiber#await`:

```ruby
server.await
```

Now that our program is complete, let's run it (we can run two separate Telnet
sessions from separate terminal windows):

```
sharon@nf1:~$ Telnet localhost 1234
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
Please enter your name: sharon
Hello, sharon!
:enter foo
sharon has entered the room.
hi
sharon: hi
sylvain has entered the room.
sylvain: hi there!
hello
sharon: hello
...
```

## Conclusion

We now have a fully functioning bare-bones chat app able to handle hundreds or
even thousands of concurrent users, implemented in about 85 lines of code, and
including a total of 8 methods: 1 for Telnet sessions, 4 for users, 3 for rooms.
Our code is compact, easy to understand, and does not include any class
definitions.

Furthermore, any state we need to keep track of (the current room for the user,
and the list of users for each room) is conveniently held as local variables
inside the relevant methods. As discussed above, we could have encapsulated our
different entities (namely, users and rooms) as `GenServer` interfaces, but I'll
leave that as an exercise to the reader.

Also, note how fluid and idiomatic our code looks. Spinning up fibers takes no
effort, and neither does fiber messaging. We just sprinkle our code with a bunch
of `spin` `receive` and `fiber << message` and everything works concurrently.

There's a lot to be said for designing concurrent programs as collections of
autonomous actors, interacting using messages. Programming in this way requires
a shift in how we think about the different entities in our program, and in how
we get them to interact. I'll continue exploring this subject in more detail in
future articles.

You can find the complete code to the chat app
[here](https://gist.github.com/ciconia/9e2ffbc39d75a8b7433ea6df7c5ddea8). Please
feel free to [contact me](https://noteflakes.com/about#contact) if you have any
questions about this article or Polyphony in general.
