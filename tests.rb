module Leet
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
    base.send(:include, InstanceMethods)
    base.send(:extend, ClassMethods)
  end
end

# class Player
#   attr_accessor :last_name, :first_name, :id
# 
#   def playa_name
#     50000000.times{|i| i*i}
#     "#{last_name}, #{first_name}"
#   end
#   
#   def score
#     puts playa_name
#     first_name.length + last_name.length
#   end
# end
# 
# # Script
# player = Player.new
# player.first_name = "Jeff"
# player.last_name = "Casimir"
# puts player.score