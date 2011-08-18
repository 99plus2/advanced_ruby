# Logging

## Custom Logging

The Rails application log can be a busy place. What if you want to separate out a certain subset of log entries, or log something unrelated to requests? Your best best is a custom logger.

It's very easy to create and use thanks to Rails `ActiveSupport::BufferedLogger`. Imagine we want to build an audit log for our application. Start with an initializer `config/initializers/audit_logger.rb`

```ruby
module Kernel
  @@audit_log = ActiveSupport::BufferedLogger.new("log/audit.log")
  def audit(message)
    preamble = "\n[#{caller.first}] at #{Time.now}\nMessage: " 
    @@audit_log.add 0, preamble + message.inspect
  end
end
```

We create the class variable `@@audit_log` within Kernel then define the `audit` method to accept a message. Then anywhere in your application call the `audit` method:

```ruby
def create
  @product = Product.new(params[:product])
  audit @product.inspect
  if @product.save
    #...
```

Pop open `log/audit.log` and you'll find messages like this:

```plain
[/path/to/your/app/controllers/products_controller.rb:18:in `create'] at 2011-07-19 14:12:16 -0700
Message: "#<Product id: nil, title: \"Apples\", price: nil, description: nil, image_url: nil, created_at: nil, updated_at: nil, stock: 0>"
```

Tweak the formatting to your liking, then add auditing wherever needed in your application!

## Distributed Logging

That kind of approach works great for a single instance, but what about coordinating multiple machines or logging from non-Ruby processes? Then you need a distributed logging system.

I took a poll of Ruby developers and three options stood out:

* 3rd party logging services like [Papertrail](https://papertrailapp.com/)
* Open source with commercial support [Syslog-ng](http://www.balabit.com/network-security/syslog-ng)
* Open source [Graylog2](http://graylog2.org)

The third party services are definitely the easiest to work with, but you're incurring extra costs and losing lots of control. If I were working on a small team and didn't have dedicated DevOps staff, I'd definitely go this route.

Syslog-ng is probably the most powerful of the three, but it's no fun to work with. The setup process was referred to as "black arts" by one developer. It requires installation on both the client and server sides, which is a lot of work. It's a pure Unix solution that doesn't leverage any Ruby.

Finally Graylog2 is quite interesting. You run a Java-based server backed by a MongoDB database, then submit log messages over UDP from a variety of client libraries. Because it relies on simple network protocols, the client-side setup is minimal. If logging every single entry is of critical importance and your server network experiences volatility, then the "fire and forget" nature of UDP is not going to be a good fit. But if you're ok with the possibility of a very occassional slip, then Graylog2 is a solid choice.

### Graylog2 Server Setup

The server setup on a Unix system is painless:

* Install and setup MongoDB if not already available (`brew install mongodb` using Homebrew for OS X)
* Download and decompress the server from https://github.com/Graylog2/graylog2-server
* Copy the `graylog2.conf.example` to `/etc/graylog2.conf` and edit with necessary MongoDB credentials. Also, changing the host from `localhost` to `127.0.0.1` was necessary due to a Java quirk on OS X.
* Start the server with `java -jar graylog2-server.jar`

### Graylog2 as Rails Logger

With the server running, let's try to use it for our normal Rails application logging instead of a `production.log`.

#### Install the Gem

Open your `Gemfile` and add a dependency on `gelf`. Run `bundle` to setup the dependency.

#### Configuring the Logger

Open `config/application.rb` and inside `class Application` add:

```ruby
config.colorize_logging = false
config.logger = GELF::Logger.new("127.0.0.1", 12201, { :facility => "your_application_name" })
```

Normal Rails logging uses terminal colorization which looks crazy when you send it to other services, so we turn the colors off. 

Then `config.logger` changes the Rails logger to use an instance of `GELF::Logger`. The instance needs:

* The ip of the Graylog2 server
* The port
* (Optionally) a "facility" name for categorizing messages from this server on the log server

Restart the Rails server and you're good to go...maybe? How do we check out the results?

#### Graylog2 Web Interface

Graylog2 offers a Rails-based web interface to view, search, and manipulate the logs. If your machine is already setup with Ruby, then it's easy to get the web interface going.

* Download the code from https://github.com/Graylog2/graylog2-web-interface
* Edit the `config/mongoid.yml` to connect to the MongoDB server on the Graylog2 server. Note that the web interface and logging server could run on different machines.
* Run `bundle` from the project directory to setup dependencies
* Start the server in production mode: `rails server -e production`
* Open the address in a browser and create a new user if one hasn't been created already
* See your log entries pouring in!

#### Dealing with Exceptions

You probably don't write bugs, but maybe someone else on your team does. Then they're going to cause exceptions in the Rails app. The exceptions should get logged as part of the normal logging facility, but there's also another approach.

Graylog2 offers a Rack middleware just for logging exceptions. From inside your Rack-based application:

* Add a dependency on `graylog2_exceptions`
* `bundle` to setup the gem
* For Rails, load the middleware by editing `config/application.rb` and adding this with the correct ip address:

```
config.middleware.use "Graylog2Exceptions", { :hostname => 'graylog2.server.ip.address', :port => '12201', :level => 0 }
```

* Or, for a Sinatra application:

```
use  Graylog2Exceptions, { :local_app_name => "MyApp", :hostname => 'graylog2.server.ip.address', :port => 12201, :level => 0 }
set :raise_errors, true
```

Start your server, cause an exception, and see it pop up in the Graylog2 interface.

#### Non-Web Logging

Want to log messages from a background job running through Resque or similar? No problem. Somewhere in the setup of your worker object, setup a `Logger` object and define a convenience method for posting message:

```
@audit_log = GELF::Logger.new("graylog2.ip.address", 12201, { :facility => "background_job_name" })
def audit(message)
  preamble = "\n[#{caller.first}] at #{Time.now}\nMessage: " 
  @@audit_log.add 0, preamble + message.inspect
end
```

Then call `audit` whenever you want to record data. There are other options you can use to structure the data for GELF here: http://rdoc.info/github/Graylog2/gelf-rb/master/GELF/Notifier

# Writing C in Your Ruby

Don't do it. Well, don't do it until it's clear you need it _or_ you've already written the C libraries and want to take advantage of them from Ruby.

## Write Once, Run Someplace

The first problem is that each Ruby interpreter has quirks when it comes to running C on the local OS. You'd like your code to run on Mac, Windows, and Linux versions of the MRI interpreter, but running on JRuby/JVM for each would be nice too. If you stick with the straight C approach, you'll have to customize the code for each of those six platforms. And that's not the Ruby way.

## FFI

The FFI (Foreign Function Interface) project is a minimal abstraction shim to make your life easier. You gain the speed of native code but can still port it between architectures.

The authors claim that:

* It has a very intuitive DSL
* It supports all C native types
* It supports C structs (also nested), enums and global variables
* It supports callbacks
* It has smart methods to handle memory management of pointers and structs

### Demo

* Install the `ffi` gem with `gem install ffi`
* Open `irb`
* Try out this code to use native libc:

```ruby
require 'ffi'

module MyLib
  extend FFI::Library
  ffi_lib 'c'
  attach_function :puts, [ :string ], :int
end

MyLib.puts 'Native code in your Ruby!'
```

### More Information

The project provides a few snippet samples: https://github.com/ffi/ffi/tree/master/samples

Then examples with more depth including memory management: https://github.com/ffi/ffi/wiki/Examples

But to really understand how it can be used, there are many open source projects using FFI: https://github.com/ffi/ffi/wiki/projects-using-ffi

# NoSQL Integration

A year ago everywhere you went people were talking about NoSQL in our community. It's cooled down a bit now, but the result of that excitement is that you have many options at your disposal.

## MongoDB

MongoDB has emerged as the most popular document database in the Rails community. There are concerns about the data integrity and the "eventually consistent" nature of the data distribution, but there are many projects using the database with great success.

### Adapters

You have two options for using Mongo from Ruby/Rails: MongoMapper and Mongoid.

#### MongoMapper

MongoMapper, driven primarilly by John Nunemaker, attempts to bring some of the niceties of `ActiveRecord` into the Mongo world. This library is popular and is usually the choice for people making their first leap into MongoDB.

More information is at http://mongomapper.com/

#### Mongoid

Mongoid is, according to statistics, the slightly more popular choice. It still mimics some functionality of `ActiveRecord`, but does so in a slightly cleaner way than MongoMapper. The development team is larger and, personally, I trust the Computer Science skills of the people behind it a bit more. Between the two, Mongoid would be my clear choice.

More info at http://mongoid.org/

## Key-Value Stores

The big area for growth right now in the "NoSQL" world are key-value stores. 

### Memcached

Memcache is kinda the old guard in this realm. It's simple and it works. If you want to store key-value data in RAM it's reliable and easy to setup. There are client libraries for just about every language and platform.

### Redis

The new hotness is Redis. It does the job that Memcached did and adds a lot of functionality. 

For instance, you can perform atomic operations. On memcache, you might fetch a value, increment it, then save the result. With Redis, you can just issue a single instruction to increment the counter.

It also implements simple data structures including hashes, lists, and sorted sets.

We're still figuring out the right ways to take advantage of Redis, but some popular options include:

* With the [Resque](https://github.com/defunkt/resque) library for coordinating background jobs
* With [Redis-Store](https://github.com/jodosha/redis-store) for storing translations, sessions, and caching pages/page fragments
* Manipulating native Redis objects with [redis-rb](https://github.com/ezmobius/redis-rb)

# Concurrency

Concurrent programming is hard. But as your push to scale applications it can make for huge performance improvements.

## Threads

The simplest method of concurrency is using Ruby threads. For example:

```ruby
begin
  numbers = Thread.new do
	100.times{ sleep 0.1; print "1" }
  end  
  letters = Thread.new do
 	100.times{ print "a"; sleep 0.1 }  
  end
  sleep 10
  numbers.join
  letters.join
end
```

Things to know about threads:

* Ruby will automatically switch between threads every 10ms
* If execution of the containing method completes and there isn't a `.join` for the thread, it will be terminated
* Threads all run in the same process, so they all stop during garbage collection
* Threads can deadlock

Overall, threads can give you some parallelism without much work. But the performance gains are limited.

## Fibers and Continuations

If you're comfortable with programming concurrent systems, them Ruby 1.9's fibers (also called continuations) are for you.

The best known usage of Fibers is with the EventMachine library: https://github.com/eventmachine/eventmachine/wiki

Generally, Fibers are powerful because you as the developer control when they start and stop. They are a lot of work because, well, you as the developer control when they start and stop. 

In general, the complexity of programming fibers means that they'll be implemented in lower-level libraries like EventMachine, then we can use the APIs provided by the libraries in our application code.

Because of the nature of the MRI interpreter, Fibers still suffer from lockout during garbage collection. Platforms with more advanced GC, like Rubinus, will be able to improve this situation as they mature.

## Cooperating Processes

Practically speaking, the best way to implement concurrency for most Ruby applications is to coordinate with worker processes.

### Native-Ruby Coordination

There are several options for coordinating Ruby processes like DRb and Rinda. There's a whole book about the subect, [Distributed Programming with Ruby](http://www.amazon.com/Distributed-Programming-Ruby-Mark-Bates/dp/0321638360/ref=sr_1_1?ie=UTF8&qid=1313684259&sr=8-1).

It's a bit of work to setup and, in my experience, the libraries are not so stable. You'll spend a decent amount of time/energy making sure the intermediary server stays up.

### DelayedJob

The dead-simple method for handling asyncronous processing, especially for Rails applications, is [DelayedJob](https://github.com/tobi/delayed_job).

It is an excellent choice for:

* Experimenting with background processes
* Learning how to build effective background workers
* Systems with relatively infrequent background needs

The problem with DelayedJob is that it goes through the database. Our databases are built to optimize for reading, but the nature of database-as-job-queue is to write, read, and delete frequently. On a system that's spinning off dozens, hundreds, or thousands of background jobs you're going to thrash your database.

### Resque

The latest hotness is Resque, a worker queue backed by Redis. Redis, being an in-memory database, is awesome for frequent reads, writes, and deletes. 

Resque was created by Github and, in powering their site, processes a bazillion background jobs per day. The process is simple:

* Post jobs to the queue
* Workers check the queue and
** Mark a job as reserved
** Do the work
** Remove the job

There is also a Sinatra app for monitoring your queues and workers.

Overall, Resque workers are my preferred approach to break apart functionality of slow applications.

# Editor Notes

## Textmate

* Bundle for Rails: https://github.com/drnic/ruby-on-rails-tmbundle
* Bundle for Sinatra: https://github.com/blinklys/sinatra-tmbundle

## Vim

* Rails.vim: https://github.com/tpope/vim-rails
* NerdTree: http://www.vim.org/scripts/script.php?script_id=1658

# General

* People: http://peepcode.com/products/peepopen

# Other Topics

## Deployment

* RVM
* Passenger