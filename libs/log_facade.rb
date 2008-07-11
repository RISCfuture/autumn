# Defines the Autumn::LogFacade class, which makes it easier for Stems and
# Leaves to add their information to outgoing log messages.

module Autumn
  
  # This class is a facade for Ruby's +Logger+ that adds additional information
  # to log entries. LogFacade will pass any method calls onto a Logger instance,
  # but reformat log entries to include an Autumn object's type and name.
  #
  # For example, if you wanted a LogFacade for a Leaf named "Scorekeeper", you
  # could instantiate one:
  #
  #  facade = LogFacade.new(logger, 'Leaf', 'Scorekeeper')
  #
  # And a call such as:
  #
  #  facade.info "Starting up"
  #
  # Would be reformatted as "Scorekeeper (Leaf): Starting up".
  #
  # In addition, this class will log messages to STDOUT if the +debug+ global
  # option is set. Instantiation of this class is handled by Genesis and should
  # not normally be done by the user.
  
  class LogFacade
    # The Autumn object type (typically "Stem" or "Leaf").
    attr :type
    # The name of the Autumn object.
    attr :name
    
    # Creates a new facade for +logger+ that prepends type and name information
    # to each log message.
    
    def initialize(logger, type, name)
      @type = type
      @name = name
      @logger = logger
      @stdout = Speciator.instance.season(:logging) == 'debug'
    end
    
    def method_missing(meth, *args) # :nodoc:
      if args.size == 1 and args.only.kind_of? String then
        args = [ "#{name} (#{type}): #{args.only}" ]
      end
      @logger.send meth, *args
      puts (args.first.kind_of?(Exception) ? (args.first.to_s + "\n" + args.first.backtrace.join("\n")) : args.first) if @stdout
    end
  end
end
