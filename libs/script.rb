require 'getoptlong'
require 'rdoc/usage'
require 'libs/generator'

module Autumn # :nodoc:
  
  # Manages data used by the script/generate and script/destroy scripts. This
  # class is instantiated by the script, and manages the script's data and
  # encapsulates common functionality between the two scripts. The object must
  # be initialized and parse_argv must be called before all attributes are ready
  # for access.
  
  class Script # :nodoc:
    # The name of the Autumn object to be created.
    attr :name
    # The type of object to be created (e.g., "leaf").
    attr :object
    # The version control system in use for this project, or nil if none is being used for this transaction.
    attr :vcs
    # The Generator instance used to create files.
    attr :generator
    
    # Creates a new instance.
    
    def initialize
      @generator = Autumn::Generator.new
    end
    
    # Parses +ARGV+ or similar array. Normally you would pass +ARGV+ into this
    # method. Populates the +object+ and +name+ attributes and returns true.
    # Outputs an error and returns false if the given arguments are invalid.
    
    def parse_argv(argv)
      if ARGV.length != 2 then
        $stderr.puts "Please specify an object (e.g., 'leaf') and its name (e.g., 'Scorekeeper')."
        return false
      end

      @object = ARGV.shift
      @name = ARGV.shift
      
      return true
    end
    
    # Determines the version control system in use by this project and sets the
    # +vcs+ attribute to its name (<tt>:cvs</tt>, <tt>:svn</tt>, or
    # <tt>:git</tt>).
    
    def use_vcs
      @vcs = find_vcs
    end
    
    # Calls the method given by the symbol, with two arguments: the +name+
    # attribute, and an options hash verbosity enabled and the VCS set to the
    # value of +vcs+.
    
    def call_generator(meth)
      generator.send(meth, name, :verbose => true, :vcs => vcs)
    end
    
    private
    
    def find_vcs
      return :svn if File.exist? '.svn' and File.directory? '.svn'
      return :cvs if File.exist? 'CVS' and File.directory? 'CVS'
      return :git if File.exist? '.git' and File.directory? '.git'
      return nil
    end
  end
end
