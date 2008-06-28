require 'yaml'
require 'timeout'
require 'facets/string/partitions'
require 'facets/array/only'
require 'facets/stylize'
require 'libs/formatting'

module Autumn
  
  # This is the superclass that all Autumn leaves use. To write a leaf, sublcass
  # this class and implement methods for each of your leaf's commands. Your
  # leaf's repertoire of commands is derived from the names of the methods you
  # write. For instance, to have your leaf respond to a "!hello" command in IRC,
  # write a method like so:
  # 
  #  def hello_command(stem, sender, reply_to, msg)
  #    stem.message "Why hello there!", channel
  #  end
  #
  # You can also implement this method as:
  #
  #  def hello_command(stem, sender, reply_to, msg)
  #    return "Why hello there!"
  #  end
  #
  # Methods of the form <tt>[word]_command</tt> tell the leaf to respond to
  # commands in IRC of the form "![word]". They should accept four parameters:
  #
  # 1. the Stem that received the message,
  # 2. the sender hash for the person who sent the message (see below),
  # 3. the "reply-to" string (either the name of the channel that the command
  #    was typed on, or the nick of the person that whispered the message), and
  # 4. any text following the command. For instance, if the person typed "!eat A
  #    tasty slice of pizza", the last parameter would be "A tasty slice of
  #    pizza". This is nil if no text was supplied with the command.
  #
  # <b>Sender hashes:</b> A "sender hash" is a hash with the following keys:
  # +nick+ (the user's nickname), +user+ (the user's username), and +host+ (the
  # user's hostname). Any of these fields except +nick+ could be nil. Sender
  # hashes are used throughout the Stem and Leaf classes, as well as other
  # classes; they always have the same keys.
  # 
  # If your <tt>*_command</tt> method returns a string, it will be sent as an
  # IRC message to "reply-to" parameter.If your leaf needs to respond to more
  # complicated commands, you will have to override the
  # did_receive_channel_message method (see below). If you like, you can remove
  # the quit_command method in your subclass, for instance, to prevent the leaf
  # from responding to !quit. You can also protect that method using filters
  # (see "Filters").
  #
  # = Hook Methods
  #
  # Aside from adding your own <tt>*_command</tt>-type methods, you should
  # investigate overriding the "hook" methods, such as will_start_up,
  # did_start_up, did_receive_private_message, did_receive_channel_message, etc.
  # There's a laundry list of so-named methods you can override. Their default
  # implementations do nothing, so there's no need to call +super+.
  #
  # = Stem Convenience Methods
  #
  # Most of the IRC actions (such as joining and leaving a channel, setting a
  # topic, etc.) are part of a Stem object. If your leaf is only running off
  # of one stem, you can call these stem methods directly, as if they were
  # methods in the Leaf class. Otherwise, you will need to specify which stem
  # to perform these IRC actions on. Usually, the stem is given to you, as a
  # parameter for your <tt>*_command</tt> method, for instance.
  #
  # For the sake of convenience, you can make Stem method calls on the +stems+
  # attribute; these calls will be forwarded to every stem in the +stems+
  # attribute. For instance, to broadcast a message to all servers and all
  # channels:
  #
  #  stems.message "Ready for orders!"
  #
  # = Filters
  #
  # Like Ruby on Rails, you can add filters to each of your commands to be
  # executed before or after the command is run. You can do this using the
  # before_filter and after_filter methods, just like in Rails. Filters are run
  # in the order they are added to the chain. Thus, if you wanted to run your
  # authentication filter before you ran your preload filter, you'd write the
  # calls in this order:
  #
  #  class MyLeaf < Leaf
  #    before_filter :my_authenticate
  #    before_filter :my_preload
  #  end
  #
  # See the documentation for the before_filter and after_filter methods and the
  # README file for more information on filters.
  #
  # = Logging
  #
  # Finally, Autumn comes with a framework for logging as well. It's very
  # similar to the Ruby on Rails logging framework. To log an error message:
  #
  #  logger.error "Quiz data is missing!"
  #
  # By default the logger will only log +info+ events and above in production
  # seasons, and will log all messages for debug seasons. (See the README for
  # more on seasons.) To customize the logger, and for more information on
  # logging, see the LogFacade class documentation.
  #
  # = Colorizing and Formatting Text
  #
  # The Autumn::Formatting module contains sub-modules which handle formatting
  # for different clients (such as mIRC-style formatting, the most common). The
  # specific formatting module that's included depends on the leaf's
  # initialization options; see initialize.
  
  class Leaf
    # Default for the +command_prefix+ init option.
    DEFAULT_COMMAND_PREFIX = '!'
    
    # The LogFacade instance for this leaf.
    attr :logger
    # The Stem instances running this leaf.
    attr :stems
    # The configuration for this leaf.
    attr :options

    # Instantiates a leaf. This is generally handled by the Foliater class.
    # Valid options are:
    # 
    # +command_prefix+:: The string that must precede all command names (default
    #                    "!")
    # +responds_to_private_messages+:: If true, the bot responds to known
    #                                  commands sent in private messages.
    # +logger+:: The LogFacade instance for this leaf.
    # +database+:: The name of a custom database connection to use.
    #
    # As well as any user-defined options you want.
    
    def initialize(opts={})
      @port = opts.delete :port
      @options = opts
      @options[:command_prefix] ||= DEFAULT_COMMAND_PREFIX
      @break_flag = false
      @logger = options[:logger]
      
      @stems = Array.new
      # Let the stems array respond to methods as if it were a single stem
      class << @stems
        def method_missing(meth, *args)
          if all? { |stem| stem.respond_to? meth } then
            collect { |stem| stem.send(meth, *args) }
          else
            super
          end
        end
      end
    end
    
    # Simplifies method calls for one-stem leaves.
    
    def method_missing(meth, *args) # :nodoc:
      if stems.size == 1 then
        stems.only.respond meth, *args
      else
        super
      end
    end
    
    ########################## METHODS INVOKED BY STEM #########################
    
    def stem_ready(stem) # :nodoc:
      return unless Thread.exclusive { stems.ready?.all? }
      database { startup_check }
    end
    
    def irc_privmsg_event(stem, sender, arguments) # :nodoc:
      database do
        if arguments[:channel] then
          parse_for_command stem, sender, arguments
          did_receive_channel_message stem, sender, arguments[:channel], arguments[:message]
        else
          parse_for_command stem, sender, arguments if options[:respond_to_private_messages]
          did_receive_private_message stem, sender, arguments[:message]
        end
      end
    end

    def irc_join_event(stem, sender, arguments) # :nodoc:
      database { someone_did_join_channel stem, sender, arguments[:channel] }
    end

    def irc_part_event(stem, sender, arguments) # :nodoc:
      database { someone_did_leave_channel stem, sender, arguments[:channel] }
    end

    def irc_mode_event(stem, sender, arguments) # :nodoc:
      database do
        if arguments[:recipient] then
          gained_usermodes(stem, arguments[:mode]) { |prop| someone_did_gain_usermode stem, arguments[:recipient], prop, arguments[:parameter], sender }
          lost_usermodes(stem, arguments[:mode]) { |prop| someone_did_lose_usermode stem, arguments[:recipient], prop, arguments[:parameter], sender }
        elsif arguments[:parameter] and stem.server_type.privilege_mode?(arguments[:mode]) then
          gained_privileges(stem, arguments[:mode]) { |prop| someone_did_gain_privilege stem, arguments[:channel], arguments[:parameter], prop, sender }
          lost_privileges(stem, arguments[:mode]) { |prop| someone_did_lose_privilege stem, arguments[:channel], arguments[:parameter], prop, sender }
        else
          gained_properties(stem, arguments[:mode]) { |prop| channel_did_gain_property stem, arguments[:channel], prop, arguments[:parameter], sender }
          lost_properties(stem, arguments[:mode]) { |prop| channel_did_lose_property stem, arguments[:channel], prop, arguments[:parameter], sender }
        end
      end
    end

    def irc_topic_event(stem, sender, arguments) # :nodoc:
      database { someone_did_change_topic stem, sender, arguments[:channel], arguments[:topic] }
    end

    def irc_invite_event(stem, sender, arguments) # :nodoc:
      database { someone_did_invite stem, sender, arguments[:recipient], arguments[:channel] }
    end

    def irc_kick_event(stem, sender, arguments) # :nodoc:
      database { someone_did_kick stem, sender, arguments[:channel], arguments[:recipient], arguments[:message] }
    end

    def irc_notice_event(stem, sender, arguments) # :nodoc:
      database do
        if arguments[:recipient] then
          did_receive_notice stem, sender, arguments[:recipient], arguments[:message]
        else
          did_receive_notice stem, sender, arguments[:channel], arguments[:message]
        end
      end
    end

    def irc_nick_event(stem, sender, arguments) # :nodoc:
      database { nick_did_change stem, sender, arguments[:nick] }
    end

    def irc_quit_event(stem, sender, arguments) # :nodoc:
      database { someone_did_quit stem, sender, arguments[:message] }
    end
    
    ########################### OTHER PUBLIC METHODS ###########################
    
    # Invoked just before the leaf starts up. Override this method to do any
    # pre-startup tasks you need. The leaf is fully initialized and all methods
    # and helper objects are available.
    
    def will_start_up
    end
    
    # Performs the block in the context of a database, referenced by symbol. For
    # instance, if you had defined in database.yml a connection named
    # "scorekeeper", you could access that connection like so:
    #
    #  database(:scorekeeper) do
    #    [...]
    #  end
    #
    # If your database is named after your leaf (as in the example above for a
    # leaf named "Scorekeeper"), it will automatically be set as the database
    # context for the scope of all hook, filter and command methods. However, if
    # your database connection is named differently, or if you are working in a
    # Stem method, you will need to set the connection using this method.
    #
    # If you omit the +dbname+ parameter, it will try to guess the name of your
    # database connection using the leaf's name and the leaf's class name.
    #
    # If the database connection cannot be found, the block is executed with no
    # database scope.
    
    def database(dbname=nil)
      dbname ||= database_name
      if dbname then
        DataMapper.database(dbname) { yield }
      else
        yield
      end
    end
    
    # Trues to guess the name of the database connection this leaf is using.
    # Looks for database connections named after either this leaf's identifier
    # or this leaf's class name. Returns nil if no suitable connection is found.
    
    def database_name # :nodoc:
      return nil unless Module.constants.include? 'DataMapper' or Module.constants.include? :DataMapper
      raise "No such database connection #{options[:database]}" if options[:database] and DataMapper::Database[options[:database]].nil?
      # Custom database connection specified
      return options[:database].to_sym if options[:database]
      # Leaf config name
      return leaf_name.to_sym if DataMapper::Database[leaf_name.to_sym]
      # Leaf config name, underscored
      return leaf_name.methodize.to_sym if DataMapper::Database[leaf_name.methodize.to_sym]
      # Leaf class name
      return self.class.to_s.to_sym if DataMapper::Database[self.class.to_s.to_sym]
      # Leaf class name, underscored
      return self.class.methodize.to_sym if DataMapper::Database[self.class.methodize.to_sym]
      # I give up
      return nil
    end

    protected

    # Adds a filter to the end of the list of filters to be run before a command
    # is executed. You can use these filters to perform tasks that prepare the
    # leaf to respond to a command, or to determine whether or not a command
    # should be run (e.g., authentication). Pass the name of your filter as a
    # symbol, and an optional has of options:
    #
    # +only+:: Only run the filter for these commands
    # +except+:: Do not run the filter for these commands
    #
    # Each option can refer to a single command or an Array of commands.
    # Commands should be symbols such as <tt>:quit</tt> for the !quit command.
    #
    # Your method will be called with these parameters:
    # 
    # 1. the Stem instance that received the command,
    # 2. the name of the channel to which the command was sent (or nil if it was
    #    a private message),
    # 3. the sender hash,
    # 4. the name of the command that was typed, as a symbol,
    # 5. any additional parameters after the command (same as the +msg+
    #    parameter in the <tt>*_command</tt> methods),
    # 6. the custom options that were given to before_filter.
    #
    # If your filter returns either nil or false, the filter chain will be
    # halted and the command will not be run. For example, if you create the
    # filter:
    #
    #  before_filter :authenticate, :only => [ :quit, :reload ], :use_passwd_file => true
    # 
    # then any time the bot receives a "!quit" or "!reload" command, it will
    # first evaluate:
    #
    #  authenticate_filter <stem>, <channel>, <sender hash>, <command>, <message>, { :use_passwd_file => true }
    #
    # and if the result is not false or nil, the command will be executed.
    
    def self.before_filter(filter, options={})
      if options[:only] and not options[:only].kind_of? Array then
        options[:only] = [ options[:only] ]
      end
      if options[:except] and not options[:except].kind_of? Array then
        options[:except] = [ options[:only] ]
      end
      write_inheritable_array 'before_filters', [ [ filter.to_sym, options ] ]
    end

    # Adds a filter to the end of the list of filters to be run after a command
    # is executed. You can use these filters to perform tasks that must be done
    # after a command is run, such as cleaning up temporary files. Pass the name
    # of your filter as a symbol, and an optional has of options. See the
    # before_filter docs for more.
    #
    # Your method will be called with five parameters -- see the before_filter
    # method for more information. Unlike before_filter filters, however, any
    # return value is ignored. For example, if you create the filter:
    #
    #  after_filter :clean_tmp, :only => :sendfile, :remove_symlinks => true
    # 
    # then any time the bot receives a "!sendfile" command, after running the
    # command it will evaluate:
    #
    #  clean_tmp_filter <stem>, <channel>, <sender hash>, :sendfile, <message>, { :remove_symlinks => true }
    
    def self.after_filter(filter, options={})
      if options[:only] and not options[:only].kind_of? Array then
        options[:only] = [ options[:only] ]
      end
      if options[:except] and not options[:except].kind_of? Array then
        options[:except] = [ options[:only] ]
      end
      write_inheritable_array 'after_filters', [ [ filter.to_sym, options ] ]
    end

    # Invoked after the leaf is started up and is ready to accept commands.
    # Override this method to do any post-startup tasks you need, such as
    # displaying a greeting message.
    
    def did_start_up
    end
  
    # Invoked just before the leaf exists. Override this method to perform any
    # pre-shutdown tasks you need.
    
    def will_quit
    end

    # Invoked when the leaf receives a private (whispered) message. +sender+ is
    # a sender hash.
    
    def did_receive_private_message(stem, sender, msg)
    end

    # Invoked when a message is sent to a channel the leaf is a member of (even
    # if that message was a valid command). +sender+ is a sender hash.
    
    def did_receive_channel_message(stem, sender, channel, msg)
    end

    # Invoked when someone joins a channel the leaf is a member of. +person+ is
    # a sender hash.
    
    def someone_did_join_channel(stem, person, channel)
    end

    # Invoked when someone leaves a channel the leaf is a member of. +person+ is
    # a sender hash.
    
    def someone_did_leave_channel(stem, person, channel)
    end

    # Invoked when someone gains a channel privilege. +privilege+ can be any
    # value returned by the stem's Daemon. If the privilege is not in the hash,
    # it will be a string (not a symbol) equal to the letter value for that
    # privilege (e.g., 'v' for voice). +bestower+ is a sender hash.
    
    def someone_did_gain_privilege(stem, channel, nick, privilege, bestower)
    end

    # Invoked when someone loses a channel privilege.
    
    def someone_did_lose_privilege(stem, channel, nick, privilege, bestower)
    end

    # Invoked when a channel gains a property. +property+ can be any value
    # returned by the stem's Daemon. If the peroperty is not in the hash, it
    # will be a string (not a symbol) equal to the letter value for that
    # property (e.g., 'k' for password). If the property takes an argument (such
    # as user limit or password), it will be passed via +argument+ (which is
    # otherwise nil). +bestower+ is a sender hash.
    
    def channel_did_gain_property(stem, channel, property, argument, bestower)
    end

    # Invoked when a channel loses a property.
    
    def channel_did_lose_property(stem, channel, property, argument, bestower)
    end
    
    # Invoked when someone gains a user mode. +mode+ can be an value returned by
    # the stem's Daemon. If the mode is not in the hash, it will be a string
    # (not a symbol) equal to the letter value for that mode (e.g., 'i' for
    # invisible). +bestower+ is a sender hash.
    
    def someone_did_gain_usermode(stem, nick, mode, argument, bestower)
    end
    
    # Invoked when someone loses a user mode.
    
    def someone_did_lose_usermode(stem, nick, mode, argument, bestower)
    end
    
    # Invoked when someone changes a channel's topic. +topic+ is the new topic.
    # +person+ is a sender hash.
    
    def someone_did_change_topic(stem, person, channel, topic)
    end

    # Invoked when someone invites another person to a channel. For some IRC
    # servers, this will only be invoked if the leaf itself is invited into a
    # channel. +inviter+ is a sender hash; +invitee+ is a nick.
    
    def someone_did_invite(stem, inviter, invitee, channel)
    end

    # Invoked when someone is kicked from a channel. Note that this is called
    # when your leaf is kicked as well, so it may well be the case that
    # +channel+ is a channel you are no longer in! +kicker+ is a sender hash;
    # +victim+ is a nick.
    
    def someone_did_kick(stem, kicker, channel, victim, msg)
    end

    # Invoked when a notice is received. Notices are like channel or pivate
    # messages, except that leaves are expected _not_ to respond to them.
    # +sender+ is a sender hash; +recipient+ is either a channel or a nick.
    
    def did_receive_notice(stem, sender, recipient, msg)
    end

    # Invoked when a user changes his nick. +person+ is a sender hash containing
    # the person's old nick, and +nick+ is their new nick.
    
    def nick_did_change(stem, person, nick)
    end

    # Invoked when someone quits IRC. +person+ is a sender hash.
    
    def someone_did_quit(stem, person, msg)
    end

    # Typing this command reloads all source code for all leaves and support
    # files, allowing you to make "on-the-fly" changes without restarting the
    # process. There are two caveats, though:
    #
    # 1. If you make any change to a constant or other unchangeable value, you
    #    will need to restart the process.
    # 2. DataMapper::Base subclasses cannot be reloaded. You will need to
    #    restart the process.
    #
    # This command does not reload the YAML configuration files, only the source
    # code.
    #
    # <b>Warning:</b> If you have multiple leaves with different model classes
    # sharing the same name, you should not use this command.
    
    def reload_command(stem, sender, reply_to, msg)
      "#{leaf_name}: Reload complete; #{reload.pluralize('file')} couldn't be reloaded."
    end
    
    def quit_command(stem, sender, reply_to, msg)
      stem.quit
    end

    # Typing this command will display information about the version of Autumn
    # that is running this leaf.
    
    def autumn_command(stem, sender, reply_to, msg)
      "Autumn version 2.0.3 (3-22-08), an IRC bot framework for Ruby (http://autumn-leaves.googlecode.com)."
    end

    private
    
    def startup_check
      return if @started_up
      @started_up = true
      did_start_up
    end
    
    def parse_for_command(stem, sender, arguments)
      if arguments[:channel] or options[:respond_to_private_messages] then
        reply_to = arguments[:channel] ? arguments[:channel] : sender[:nick]
        if arguments[:message] =~ /^#{options[:command_prefix]}(\w+)\s*(.*)$/ then
          name = $1.to_sym
          meth = "#{name}_command".to_sym
          msg = $2
          msg = nil if msg.empty?
          origin = sender.merge(:stem => stem)
          if run_before_filters(name, stem, arguments[:channel], sender, name, msg) then
            response = respond meth, stem, sender, reply_to, msg
            run_after_filters name, stem, arguments[:channel], sender, name, msg if respond_to? meth
            if response and not response.empty? then
              stem.message response, reply_to
            end
          end
        end
      end
    end

    def reload
      # Not all files reload well, so we're going to take the (very rare) step
      # of catching every Exception and letting them all die silently.
      exceptions = 0
      Dir.glob("#{options[:root]}/leaves/*.rb").each do |file|
        begin
          load file
        rescue Exception
          exceptions += 1
        end
      end
      Dir.glob("#{options[:root]}/support/**/*.rb").each do |file|
        begin
          load file
        rescue Exception
          exceptions += 1
        end
      end
      #TODO it's slow to reload everything in leaves/ and support/ for every leaf, but there's not really a better way for now
      logger.info "Reloading"
      return exceptions
    end
    
    def leaf_name
      Foliater.instance.leaves.index(self)
    end

    def run_before_filters(cmd, stem, channel, sender, command, msg)
      command = cmd.to_sym
      self.class.before_filters.each do |filter, options|
        local_opts = options.dup
        next if local_opts[:only] and not local_opts.delete(:only).include? command
        next if local_opts[:except] and local_opts.delete(:except).include? command
        return false unless method("#{filter}_filter")[stem, channel, sender, command, msg, local_opts]
      end
      return true
    end

    def run_after_filters(cmd, stem, channel, sender, command, msg)
      command = cmd.to_sym
      self.class.after_filters.each do |filter, options|
        local_opts = options.dup
        next if local_opts[:only] and not local_opts.delete(:only).include? command
        next if local_opts[:except] and local_opts.delete(:except).include? command
        method("#{filter}_filter")[stem, channel, sender, command, msg, local_opts]
      end
    end

    def gained_privileges(stem, privstr)
      return unless privstr[0] == ?+
      privstr.except_first.each_char { |c| yield stem.server_type.privilege[c] }
    end

    def lost_privileges(stem, privstr)
      return unless privstr[0] == ?-
      privstr.except_first.each_char { |c| yield stem.server_type.privilege[c] }
    end

    def gained_properties(stem, propstr)
      return unless propstr[0] == ?+
      propstr.except_first.each_char { |c| yield stem.server_type.channel_mode[c] }
    end

    def lost_properties(stem, propstr)
      return unless propstr[0] == ?-
      propstr.except_first.each_char { |c| yield stem.server_type.channel_mode[c] }
    end
    
    def gained_usermodes(stem, modestr)
      return unless modestr[0] == ?+
      modestr.except_first.each_char { |c| yield stem.server_type.usermode[c] }
    end
    
    def lost_usermodes(stem, modestr)
      return unless modestr[0] == ?-
      modestr.except_first.each_char { |c| yield stem.server_type.usermode[c] }
    end

    def self.before_filters
      read_inheritable_attribute('before_filters') or []
    end

    def self.after_filters
      read_inheritable_attribute('after_filters') or []
    end
  end
end
