require 'ostruct'
require 'pathname'

module Autumn
  Config      = OpenStruct.new
  Config.root = Pathname.new(__FILE__).dirname.join('..').realpath
end
