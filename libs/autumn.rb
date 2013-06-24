require 'ostruct'
require 'pathname'

# Container module for all classes of the Autumn IRC bot library.

module Autumn
  # The current Autumn configuration.
  Config      = OpenStruct.new

  Config.root = Pathname.new(__FILE__).dirname.join('..').realpath
end
