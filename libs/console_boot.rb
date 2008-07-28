# Used by the script/console script to load the Autumn environment when IRb
# is executed.

require 'libs/genesis'

AL_ROOT = File.dirname(__FILE__)
@genesis = Autumn::Genesis.new
@genesis.boot! false
