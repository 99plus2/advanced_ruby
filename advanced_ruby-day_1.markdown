# What's New in 1.9

## Hash Syntax

The most well known change in Ruby 1.9 is the addition of a new, simplified, JavaScript-inspired hash syntax:

The traditional (and still perfectly good) syntax:

```ruby
{ :a => 'apple', :b => 'banana' }
```

When you're using 1.9 and the keys are symbols, you can write it like this:

```ruby
{ a: 'apple', b: 'banana' }
```

Nice! But the clarity breaks down when the data elements are also symbols:

```ruby
{ a: :apple, b: :banana }
```

It works fine...but it's ugly.

## Regular Expressions with Named Captures

Regular expressions too regular for you? How about some more symbols to achieve named captures!

```ruby
> match_set = "10:56:01".match(/(?<hour>\d\d):(?<min>\d\d):(?<sec>\d\d)/)
# => #<MatchData "10:56:01" hour:"10" min:"56" sec:"01"> 
> match_set[:hour]
# => "10" 
> match_set.captures[0]
# => "10" 
```

Inside the opening `(` of a capture add `?<name>` with a name of your choice. Access the results in the `MatchData` with a hash/symbol lookup.
	
## Collections

The already rich `Enumerable` class got several new methods. Here are some highlights.

### .shuffle

Randomize the elements:

```irb
[1,2,3,4,5].shuffle
# => [3, 5, 4, 1, 2]
```

### .permutation(size)

Compute the permutations of the source collection into sets of `size`:

```irb
> [1,2,3,4,5].permutation(2)
# => #<Enumerator: [1, 2, 3, 4, 5]:permutation(2)> 
> [1,2,3,4,5].permutation(2).to_a
# => [[1, 2], [1, 3], [1, 4], [1, 5], [2, 1], [2, 3], [2, 4], [2, 5], [3, 1], [3, 2], [3, 4], [3, 5], [4, 1], [4, 2], [4, 3], [4, 5], [5, 1], [5, 2], [5, 3], [5, 4]]
```

### .each_slice(size)

Cut the collection into slices of `size`, pass a block to iterate over the slices:

```irb
> [1,2,3,4,5].each_slice(2){ |data| puts data.inspect }
[1, 2]
[3, 4]
[5]
# => nil 
```

### .rotate(quantity)

Unshift elements from the left and append them to the right. Defaults to one, but you can pass a number of elements to move:

```irb
> [1,2,3,4,5].rotate
# => [2, 3, 4, 5, 1] 
> [1,2,3,4,5].rotate(2)
# => [3, 4, 5, 1, 2]
```

## UTF-8

* Files are assumed to be 7-bit ASCII
* You can specify the encoding of a file by starting it with:

```ruby
# encoding: utf-8
```

### Example:

Try running this code in IRB, from a file with the encoding line, and from a file with the encoding line removed.

```
# encoding: utf-8
str = "∂og"
puts str.length
puts str[0]
puts str.reverse
```

### References

* http://rbjl.net/27-new-array-and-enumerable-methods-in-ruby-1-9-2-keep_if-chunk
* http://pragprog.com/magazines/2010-12/whats-new-in-ruby-
* http://www.strictlyuntyped.com/2010/12/new-ruby-19-hash-syntax.html
* http://ruby.runpaint.org/regexps

# Simple Ruby Debugging

The first and most widely used method of debugging Ruby application is simply outputting text data. Let's look at a few approaches at increasing levels of expertise.
 
## Temporary Instructions

Let's next look at adding temporary instructions to our application. 

### Using Warn

Looking at the server log gave lots of great info, but it doesn't help with inspecting the values of variables or instructions. For that job, use the `warn` method of Ruby's `Kernel` object. Here's how I might insert it into the `create` method:

```ruby
def create
  @product = Product.new(params[:product])
  warn "Product before save:"
  warn @product.inspect
  if @product.save
    redirect_to @product, :notice => "Successfully created product."
  else
    render :action => 'new'
  end
end
```

Then in the output log see the results:

```plain
Product before save:
#<Product id: nil, title: "Apples", price: nil, description: nil, image_url: nil, created_at: nil, updated_at: nil, stock: 0>


Started POST "/products" for 127.0.0.1 at 2011-07-19 13:18:26 -0700
  Processing by ProductsController#create as HTML
```

Notice that the warn comes out before where the log claims it is "starting" the response. The `warn` is output immediately, while the normal logging operations are buffered and output all together. When I use warn I'll typically put in some label to the output, like the `Product before save` here. The messages for `warn` are just strings, so you can use `\n` newlines or other text formatting to make them easier to read.

### Raising Exceptions

One of my most frequently used techniques is to intentionally raise an exception. If I wanted to check out the `@product` object during the `create` method and maybe look at the parameters of the request, I'd typically do this:

```ruby
def create
  @product = Product.new(params[:product])
  raise @product.inspect
  #...
end
```

The `raise` will immediately halt execution and display a stack trace. The `raise` method accepts one parameter, a string, which will be output as the error message.

With this usage you'd see something like this:

```
RuntimeError in ProductsController#create
#<Product id: nil, title: "Apples", price: nil, description: nil, image_url: nil, created_at: nil, updated_at: nil, stock: 0>
```

The first line specifying that it was a general `RuntimeError` exception and the second line is the message, the result of our `inspect`. Generally `inspect` is a better choice than `to_s` as it'll show more about the object's internal state.

This is my favorite debugging technique when writing Ruby applications because you don't have to dig through anything -- execution halts right at your message.

# Serious Debugging

Most of the time simple output statements using `warn`, `raise`, or a logger will help you find your issue. But sometimes you need the big guns, and that means `ruby-debug`.

## Ruby-Debug

The `ruby-debug` package has had some rocky times during the transition from Ruby 1.8.7 to 1.9.2 and beyond. But now, finally, the debugger is reliable and usable.

### Installation

Assuming you're writing your app in Ruby 1.9 and using Bundler, just add the dependency to your development gems:

```ruby
group :development do
  gem 'ruby-debug19'
end
```

If you left off the `19` you would instead get the package for use with 1.8.7 and it's incompatible with 1.9. Note that the debugger relies on native extensions, so you need to have the Ruby headers and compilation tools setup on your system.

### Booting

When you start a Rails server or console, you have to explicitly enable the debugger like this:

```bash
rails server --debug
rails console --debug
```

In plain IRB or other ruby projects you can just load it by requiring:

```ruby
require 'rubygems'
require 'ruby-debug'
```

Now the debugger is loaded. Anywhere we insert breakpoints will trigger it.

### Interrupting Execution

Wherever you want to inspect execution just add a call to `debugger` like this:

```ruby
(0..99).to_a.each do |i|
  debugger if i == 50
  puts i
end
```

If the debugger is properly loaded, execution will pause and drop you into the debugger interface. 

```
experiments.rb:6
puts i
(rdb:1) 
```

Which can be read like this:

* Line 1: The line of code containing the call to `debugger`
* Line 2: The next line of code pending execution
* Line 3: The debugger prompt

Now you have incredible power available to you with a few simple commands.

### Basic Usage

#### `continue`

Say you figure out the issue and you're ready to finish the request. Just issue the `continue` instruction and execution will keep running from wherever it paused.

#### `quit`

Rarely you want to exit the application all together. Quit will halt execution without finishing the request.

#### `list`

The `list` instructions shows the context of the current code, five lines before and four lines after the current execution point.

#### `next`

The `next` instruction will run the following instruction in the current context and move the marker to the next line in that context. 

#### `step`

The `step` command, on the other hand, will move the execution marker to the next instruction to be executed even in a called method. This can be useful if you really want to dig through Rails internals, but for most purposes I find `step` impractical.

#### `eval`

Eval a chunk of Ruby code in the current context and display the result. For the example above:

```irb
(rdb:1) eval i
50
```

#### Watching Variables with `display`

Typically when running the debugger you're interested in how a variable changes over a series of instructions. First, let's trigger the debugger multiple times:

```ruby
(0..99).to_a.each do |i|
  debugger if i % 10 == 0
  puts i
end
```

Run that code then use the `display` command like this:

```irb
> ruby experiments.rb 
experiments.rb:5
@x = 5 * i
(rdb:1) display @x
1: @x = 0
(rdb:1) display i
2: i = 1
(rdb:1) continue
1: @x = 50
2: i = 11
experiments.rb:5
@x = 5 * i
(rdb:1) continue
1: @x = 100
2: i = 21
experiments.rb:5
@x = 5 * i
(rdb:1) 
```

When you `display` a variable it will show up for all further debugger calls in that process. Want to stop displaying a variable? Just call `undisplay` with the number displayed next to the variable. So in this case, I'd see the `1:` next to `@x` and call `undisplay 1`.

#### Dropping into IRB

Not satisfied with those options? Just call the `irb` instruction and the debugger will drop you into a normal IRB console. Use all your normal Ruby functions and tricks, then `exit` to get back to the debugger. You can continue to invoke other instructions and any data you created/changed in the IRB session is brought back into the debugging session.

### References

* Extensive details about `ruby-debug` are available here: http://bashdb.sourceforge.net/ruby-debug.html

## Memory
### Profiling

PerfTools.rb is a port of Google's Perftools: https://github.com/tmm1/perftools.rb

#### Usage

* `gem install perftools.rb`
* Collect data by:
  * Using a block:

```ruby
require 'perftools'
PerfTools::CpuProfiler.start("/tmp/add_numbers_profile") do
  5_000_000.times{ 1+2+3+4+5 }
end
```

  * Using Start/Stop

```ruby
require 'perftools'
PerfTools::CpuProfiler.start("/tmp/add_numbers_profile")
5_000_000.times{ 1+2+3+4+5 }
PerfTools::CpuProfiler.stop
```

  * Running Externally

```ruby
CPUPROFILE=/tmp/my_app_profile RUBYOPT="-r`gem which perftools | tail -1`" ruby my_app.rb
```

Where `my_app.rb` is the external file

#### Reports

With the data file generated you can create a variety of reports. The simplest is the plain text table. Run this from the command line:

```
pprof.rb --text /tmp/add_numbers_profile
```

To generate output like this:

```
Total: 1735 samples
    1487  85.7%  85.7%     1735 100.0% Integer#times
     248  14.3% 100.0%      248  14.3% Fixnum#+
```

Where the columns indicate:

1. Number of profiling samples in this function
2. Percentage of profiling samples in this function
3. Percentage of profiling samples in the functions printed so far
4. Number of profiling samples in this function and its callees
5. Percentage of profiling samples in this function and its callees
6. Function name

#### References

* https://github.com/tmm1/perftools.rb
* http://google-perftools.googlecode.com/svn/trunk/doc/cpuprofile.html#pprof
* http://www.igvita.com/2009/06/13/profiling-ruby-with-googles-perftools/

# Ruby Objects

## Methods and Blocks

Writing methods that work with blocks is actually not too complicated. Let's look at a few examples:

### A Required Block

```ruby
def ten_times(&block)
  10.times do
    yield
  end
end
```

#### Usage

```irb
> ten_times
LocalJumpError: no block given (yield)
	from (irb):3:in `block in ten_times'
> ten_times{ puts "Hello, World" }
Hello, World
Hello, World
Hello, World
Hello, World
Hello, World
Hello, World
Hello, World
Hello, World
Hello, World
Hello, World
 => 10 
```

So the method will not run unless the block is given.

### An Optional Block

We can make the block optional by removing it from the list of parameters. Every Ruby method implicitly accepts a block, but it will only use that block when `yield` is called.

```ruby
def ten_times
  10.times do
    yield if block_given?
  end
end
```

Note the `block_given?` method which returns `true` or `false` depending on whether a block was passed in. If `yield` is called when there is *no* block, then a `LocalJumpError` will be raised.

### With Parameters

Often you want to use data within the block itself. Here's how:

```ruby
def ten_times(&block)
  10.times do |index|
    yield(index)
  end
end
```

Here the `index` gets passed into `yield`, which is then made available by specifying a local variable in the pipes of the block:

```irb
> ten_times{|count| puts "Hello, World: Iteration #{count}"}
Hello, World: Iteration 0
Hello, World: Iteration 1
Hello, World: Iteration 2
Hello, World: Iteration 3
Hello, World: Iteration 4
Hello, World: Iteration 5
Hello, World: Iteration 6
Hello, World: Iteration 7
Hello, World: Iteration 8
Hello, World: Iteration 9
 => 10 
```

## Monkeypatching

In Ruby, all classes can be modified at runtime, a technique commonly known as "Monkeypatching".

### Example:

```
> "hello".leet_speak
# NoMethodError: undefined method `leet_speak' for "hello":String
> class String
>   def leet_speak
>     self.gsub("e","3").gsub("l", "!")
>     end
>   end
# => nil 
> "hello".leet_speak
# => "h3!!o" 
```

We reopen the class just the same as defining a new one. If you define a new method it will be added to all new and existing instances of the class. Redefining a method will overwrite that method for all instances.

### Practical Application

In general, don't do it.

It is the right technique when you're using a library, particularly a third party library, that has a bug or insufficient flexibility to fit your application. The monkeypatch should be a temporary fix, like a piece of duct tape, while a real patch is being developed.

If you're really sure it should stick around, then you should at least write it into a module or "mix-in". 

## Modules & Mix-ins

Ruby classes can only inherit from one parent, but they can mix in multiple modules. As such, modules are a powerful way to modularize and reuse chunks of your code across objects.

### Example

We can write a module like this:

```ruby
module Leet
  def leet_speak
	self.gsub("e","3").gsub("l", "!")
  end
end
```

Then utilize that from a class:

```ruby
class LeetString < String
  include Leet
end
```

Then use it:

```ruby
sample = LeetString.new("Hello, World")
# => "Hello, World" 
sample.leet_speak
# => "H3!!o, Wor!d" 
```

### Notes

By using `include`, any methods in the module were added as instance methods. If we used `extend` they would be added as class methods.

### Extension

But what if you want to write both instance and class methods in a module? There is a common pattern that accomodates that usage:

```ruby
module LeetSpeak 
  module ClassMethods
    def leet?(input)
      input.include?("!")
    end
  end
 
  module InstanceMethods
    def leet_speak
	  self.gsub("e","3").gsub("l", "!")
	end
  end
 
  def self.included(base)
    base.send :include, InstanceMethods
    base.send :extend, ClassMethods
  end 
end
```

We define two submodules, one for instance methods and one for class methods. When the outer module is included into a class the `self.included` method is triggered and the including class is passed in as `base`. 

The `.included` method then forces the including class to `include` the module named `InstanceMethods`, adding them as instance methods like a normal `include`. It then forces `base` to `extend` the `ClassMethods` module, creating class methods.

Using the module is the same as before:

```ruby
class LeetString < String
  include LeetSpeak
end
```

Then exercising both the instance and class methods:

```irb
> sample = LeetString.new("Hello, World")
# => "Hello, World" 
> sample.leet_speak
# => "H3!!o, Wor!d" 
> LeetString.leet?("0wn3d!")
# => true 
```

And that's about it!