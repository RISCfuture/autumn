require 'fileutils'
require 'getoptlong'
require 'facets'
require 'libs/generator'

module Autumn

  # Manages data used by the `script/generate` and `script/destroy` scripts.
  # This class is instantiated by the script, and manages the script's data and
  # encapsulates common functionality between the two scripts. The object must
  # be initialized and parse_argv must be called before all attributes are ready
  # for access.

  class Script
    # @return [String] The name of the Autumn object to be created.
    attr :name
    # @return [String] The type of object to be created (e.g., "leaf").
    attr :object
    # @return [:cvs, :svn, :git, nil] The version control system in use for this
    #   project, or `nil` if none is being used for this transaction.
    attr :vcs
    # @return [Generator] The Generator instance used to create files.
    attr :generator

    # Creates a new instance.

    def initialize
      @generator = Autumn::Generator.new
    end

    # Parses `ARGV` or similar array. Normally you would pass `ARGV` into this
    # method. Populates the `object` and `name` attributes and returns `true`.
    # Outputs an error to `STDERR` and returns `false` if the given arguments
    # are invalid.
    #
    # @param [Array<String>] argv The launch arguments.
    # @return [true, false] Whether the arguments are valid.

    def parse_argv(argv)
      if argv.length != 2
        $stderr.puts "Please specify an object (e.g., 'leaf') and its name (e.g., 'Scorekeeper')."
        return false
      end

      @object = argv.shift
      @name   = argv.shift

      return true
    end

    # Determines the version control system in use by this project and sets the
    # {#vcs} attribute to its name (`:cvs`, `:svn`, or `:git`).

    def use_vcs
      @vcs = find_vcs
    end

    # Calls the method given by the symbol, with two arguments: the `name`
    # attribute, and an options hash with verbosity enabled and the VCS set to
    # the value of `vcs`.
    #
    # @param [Symbol] meth The generator method name.

    def call_generator(meth)
      generator.send(meth, name, verbose: true, vcs: vcs)
    end

    private

    def find_vcs
      return :svn if File.exist?('.svn') && File.directory?('.svn')
      return :cvs if File.exist?('CVS') && File.directory?('CVS')
      return :git if File.exist?('.git') && File.directory?('.git')
      return nil
    end
  end
end
