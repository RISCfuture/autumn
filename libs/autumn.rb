require 'ostruct'

module Autumn
  Config      = OpenStruct.new
  Config.root = File.expand_path("#{File.dirname(__FILE__)}/..")
end
