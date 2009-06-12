# Defines the Autumn::Speciator class, which stores the configurations of many
# Autumn objects.

require 'singleton'

module Autumn

  # The Speciator stores the global, season, stem, and leaf configurations. It
  # generates composite hashes, so that any leaf or stem can know its specific
  # configuration as a combination of its options and those of the scopes above
  # it.
  #
  # Smaller scopes override larger ones; any season-specific options will
  # replace global options, and leaf or stem options will overwrite season
  # options. Leaf and stem options are independent from each other, however,
  # since leaves and stems share a many-to-many relationship.
  #
  # Option identifiers can be specified as strings or symbols but are always
  # stored as symbols and never accessed as strings.
  #
  # This is a singleton class; only one instance of it exists for any Autumn
  # process. However, for the sake of convenience, many other objects use a
  # +config+ attribute containing the instance.

  class Speciator
    include Singleton
  
    # Creates a new instance storing no options.
  
    def initialize
      @global_options = Hash.new
      @season_options = Hash.new
      @stem_options = Hash.autonew
      @leaf_options = Hash.autonew
    end
  
    # Returns the global-scope or season-scope config option with the given
    # symbol. Season-scope config options will override global ones.
  
    def [](sym)
      @season_options[sym] or @global_options[sym]
    end
  
    # When called with a hash: Takes a hash of options and values, and sets them
    # at the global scope level.
    #
    # When called with an option identifier: Returns the value for that option at
    # the global scope level.
  
    def global(arg)
      arg.kind_of?(Hash) ? @global_options.update(arg.rekey(&:to_sym)) : @global_options[arg]
    end
  
    # When called with a hash: Takes a hash of options and values, and sets them
    # at the season scope level.
    #
    # When called with an option identifier: Returns the value for that option
    # exclusively at the season scope level.
    #
    # Since Autumn can only be run in one season per process, there is no need
    # to store the options of specific seasons, only the current season.
  
    def season(arg)
      arg.kind_of?(Hash) ? @season_options.update(arg.rekey(&:to_sym)) : @season_options[arg]
    end
    
    # Returns true if the given identifier is a known stem identifier.
    
    def stem?(stem)
      return !@stem_options[stem].nil?
    end
    
    # When called with a hash: Takes a hash of options and values, and sets them
    # at the stem scope level.
    #
    # When called with an option identifier: Returns the value for that option
    # exclusively at the stem scope level.
    #
    # The identifier for the stem must be specified.
  
    def stem(stem, arg)
      arg.kind_of?(Hash) ? @stem_options[stem].update(arg.rekey(&:to_sym)) : @stem_options[stem][arg]
    end
    
    # Returns true if the given identifier is a known leaf identifier.
    
    def leaf?(leaf)
      return !@leaf_options[leaf].nil?
    end
  
    # When called with a hash: Takes a hash of options and values, and sets them
    # at the leaf scope level.
    #
    # When called with an option identifier: Returns the value for that option
    # exclusively at the leaf scope level.
    #
    # The identifier for the leaf must be specified.
  
    def leaf(leaf, arg)
      arg.kind_of?(Hash) ? @leaf_options[leaf].update(arg.rekey(&:to_sym)) : @leaf_options[leaf][arg]
    end
    
    # Yields each stem identifier and its options.
    
    def each_stem
      @stem_options.each { |stem, options| yield stem, options }
    end
    
    # Yields each leaf identifier and its options.
    
    def each_leaf
      @leaf_options.each { |leaf, options| yield leaf, options }
    end
    
    # Returns an array of all leaf class names in use.
    
    def all_leaf_classes
      @leaf_options.values.collect { |opts| opts[:class] }.uniq
    end
  
    # Returns the composite options for a stem (by identifier), as an
    # amalgamation of all the scope levels' options.
  
    def options_for_stem(identifier)
      OptionsProxy.new(@global_options, @season_options, @stem_options[identifier])
    end
    
    # Returns the composite options for a leaf (by identifier), as an
    # amalgamation of all the scope levels' options.
    
    def options_for_leaf(identifier)
      OptionsProxy.new(@global_options, @season_options, @leaf_options[identifier])
    end
  end
  
  class OptionsProxy # :nodoc:
    extend ActiveSupport::Memoizable
    
    MERGED_METHODS = [ :[], :each, :each_key, :each_pair, :each_value, :eql?,
      :fetch, :has_key?, :include?, :key?, :member?, :has_value?, :value?,
      :hash, :index, :inspect, :invert, :keys, :length, :size, :merge, :reject,
      :select, :sort, :to_a, :to_hash, :to_s, :values, :values_at ]
    
    def initialize(*hashes)
      raise ArgumentError unless hashes.all? { |hsh| hsh.kind_of? Hash }
      @hashes = hashes
      @hashes << Hash.new # the runtime settings, which take precedence over all
    end
    
    def method_missing(meth, *args, &block)
      if MERGED_METHODS.include? meth then
        merged.send meth, *args, &block
      else
        returnval = @hashes.last.send(meth, *args, &block)
        merged :reload
        returnval
      end
    end
    
    private
    
    def merged
      merged = Hash.new
      @hashes.each { |hsh| merged.merge! hsh }
      merged
    end
    memoize :merged
  end
end
