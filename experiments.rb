require 'rubygems'
require 'perftools'

PerfTools::CpuProfiler.start("/tmp/add_numbers_profile") do
  (0..500000).to_a.each do |i|
    @x = 5 * i
    if i % 10 == 0
      puts "Hello"
    end
    if i == 80
      10.times do
        10*10*10
      end
    end
  end
end
