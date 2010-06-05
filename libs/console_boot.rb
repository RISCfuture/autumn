# Used by the script/console script to load the Autumn environment when IRb
# is executed.

require 'libs/autumn'
require 'libs/genesis'

@genesis = Autumn::Genesis.new
@genesis.boot! false
