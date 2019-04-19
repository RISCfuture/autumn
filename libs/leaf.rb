module Autumn

  # This is the superclass that all Autumn leaves use. To write a leaf, sublcass
  # this class and implement methods for each of your leaf's commands. Your
  # leaf's repertoire of commands is derived from the names of the methods you
  # write. For instance, to have your leaf respond to a `!hello` command in IRC,
  # write a method like so:
  #
  # ```` ruby
  # def hello_command(stem, sender, reply_to, msg)
  #   stem.message "Why hello there!", reply_to
  # end
  # ````
  #
  # You can also implement this method as:
  #
  # ```` ruby
  # def hello_command(stem, sender, reply_to, msg)
  #   return "Why hello there!"
  # end
  # ````
  #
  # Methods of the form `[word]_command` tell the leaf to respond to commands in
  # IRC of the form `![word]`. They should accept four parameters:
  #
  # 1. the {Stem} that received the message,
  # 2. the sender hash for the person who sent the message (see below),
  # 3. the "reply-to" string (either the name of the channel that the command
  #    was typed on, or the nick of the person that whispered the message), and
  # 4. any text following the command. For instance, if the person typed "!eat A
  #    tasty slice of pizza", the last parameter would be "A tasty slice of
  #    pizza". This is `nil` if no text was supplied with the command.
  #
  # ### Sender hashes
  #
  # A "sender hash" is a hash with the following keys:
  #
  # |         |        |                     |
  # |:--------|:-------|:--------------------|
  # | `:nick` | String | the user's nickname |
  # | `:user` | String | the user's username |
  # | `:host` | String | the user's hostname |
  #
  # Any of these fields except `:nick` could be nil. Sender hashes are used
  # throughout the Stem and Leaf classes, as well as other classes; they always
  # have the same keys.
  #
  # ### Return values
  #
  # If your `*_command` method returns a string, it will be sent as an IRC
  # message to the "reply-to" parameter. If your leaf needs to respond to more
  # complicated commands, you will have to override the
  # {#did_receive_channel_message} method (see below).
  #
  # If you want to separate view logic from the controller, you can use ERb to
  # template your views. See the render method for more information.
  #
  # ### Removing commands
  #
  # If you like, you can remove the `quit_command` method in your subclass, for
  # instance, to prevent the leaf from responding to `!quit`. You can also
  # protect that method using filters (see "Filters").
  #
  # Hook Methods
  # ------------
  #
  # Aside from adding your own `*_command`-type methods, you should investigate
  # overriding the "hook" methods, such as {#will_start_up}, {#did_start_up},
  # {#did_receive_private_message}, {#did_receive_channel_message}, etc. There's
  # a laundry list of so-named methods you can override. Their default
  # implementations do nothing, so there's no need to call `super`.
  #
  # Stem Convenience Methods
  # ------------------------
  #
  # Most of the IRC actions (such as joining and leaving a channel, setting a
  # topic, etc.) are part of a {Stem} object. If your leaf is only running off
  # of one stem, you can call these stem methods directly, as if they were
  # methods in the Leaf class. Otherwise, you will need to specify which stem
  # to perform these IRC actions on. Usually, the stem is given to you, as a
  # parameter for your `*_command` method, for instance.
  #
  # For the sake of convenience, you can make Stem method calls on the `stems`
  # attribute; these calls will be forwarded to every stem in the `stems`
  # attribute. For instance, to broadcast a message to all servers and all
  # channels:
  #
  # ```` ruby
  # stems.message "Ready for orders!"
  # ````
  #
  # Filters
  # -------
  #
  # Like Ruby on Rails, you can add filters to each of your commands to be
  # executed before or after the command is run. You can do this using the
  # {.before_filter} and {.after_filter} methods, just like in Rails. Filters
  # are run in the order they are added to the chain. Thus, if you wanted to run
  # your preload filter before you ran your cache filter, you'd write the calls
  # in this order:
  #
  # ```` ruby
  # class MyLeaf < Leaf
  #   before_filter :my_preload
  #   before_filter :my_cache
  # end
  # ````
  #
  # See the documentation for the {.before_filter} and {.after_filter} methods
  # and the README file for more information on filters.
  #
  # Authentication
  # --------------
  #
  # If a leaf is initialized with a hash for the `authentication` option, the
  # values of that hash are used to choose an authenticator that will be run
  # before each command. This authenticator will determine whether or not the
  # user can run that command. The options that can be specified in this hash
  # are:
  #
  # |           |               |                                                                                                                                                                                                                                          |
  # |:----------|:--------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
  # | `:type`   | String        | The name of a class in the {Autumn::Authentication} module, in snake_case. Thus, if you wanted to use the {Autumn::Authentication::Password} class, which does password-based authentication, you'd set this value to `password`.        |
  # | `:only`   | Array<Symbol> | A list of protected commands for which authentication is required; all other commands are unprotected.                                                                                                                                   |
  # | `:except` | Array<Symbol> | A list of unprotected commands; all other commands require authentication.                                                                                                                                                               |
  # | `:silent` | true, false   | Normally, when someone fails to authenticate himself before running a protected command, the leaf responds with an error message (e.g., "You have to authenticate with a password first"). Set this to `true` to suppress this behavior. |
  #
  # In addition, you can also specify any custom options for your authenticator.
  # These options are passed to the authenticator's `initialize` method. See the
  # classes in the Autumn::Authentication module for such options.
  #
  # If you annotate a command method as protected, the authenticator will be run
  # unconditionally, regardless of the `:only` or `:except` options:
  #
  # ```` ruby
  # class Controller < Autumn::Leaf
  #   def destructive_command(stem, sender, reply_to, msg)
  #     # ...
  #   end
  #   ann :destructive_command, protected: true
  # end
  # ````
  #
  # Logging
  # -------
  #
  # Autumn comes with a framework for logging as well. It's very similar to the
  # Ruby on Rails logging framework. To log an error message:
  #
  # ```` ruby
  # logger.error "Quiz data is missing!"
  # ````
  #
  # By default the logger will only log `info` events and above in production
  # seasons, and will log all messages for debug seasons. (See the README for
  # more on seasons.) To customize the logger, and for more information on
  # logging, see the {LogFacade} class documentation.
  #
  # Colorizing and Formatting Text
  # ------------------------------
  #
  # The {Autumn::Formatting} module contains sub-modules which handle formatting
  # for different clients (such as mIRC-style formatting, the most common). The
  # specific formatting module that's included depends on the leaf's
  # initialization options; see {#initialize}.

  class Leaf
    extend Anise::Annotations

    # Default for the `command_prefix` init option.
    DEFAULT_COMMAND_PREFIX = '!'
    @@view_alias           = Hash.new { |h, k| k }

    # @return [LogFacade] The logger instance for this leaf.
    attr :logger
    # @return [Array<Stem>] The Stem instances running this leaf.
    attr :stems
    # @return [Hash<Symbol, Object>] The configuration for this leaf.
    attr :options

    # Instantiates a leaf. This is generally handled by the {Foliater} class.
    #
    # @param [Hash] opts Initialization options, as well as any user-defined
    #   options you wish.
    # @option options [String] :command_prefix (DEFAULT_COMMAND_PREFIX) The
    #   string that must precede all command names.
    # @option options [true, false] :responds_to_private_messages If `true`, the
    #   bot responds to known commands sent in private messages.
    # @option options [LogFacade] :logger The logger instance for this leaf.
    # @option options [String] :database The name of a custom database
    #   connection to use.
    # @option options [String] :formatter (Autumn::Formatting::DEFAULT) The name
    #   of an Autumn::Formatting class to use as the formatted.
    # @option options [Hash] :authentication Additional authentication options
    #   (see class documentation).

    def initialize(opts={})
      @port                     = opts[:port]
      @options                  = opts
      @options[:command_prefix] ||= DEFAULT_COMMAND_PREFIX
      @break_flag               = false
      @logger                   = options[:logger]

      @stems = Set.new
      # Let the stems array respond to methods as if it were a single stem
      class << @stems
        def method_missing(meth, *args)
          if all? { |stem| stem.respond_to? meth }
            collect { |stem| stem.send(meth, *args) }
          else
            super
          end
        end
      end
    end

    # @private
    def preconfigure
      if options[:authentication]
        @authenticator = Autumn::Authentication.const_get(options[:authentication]['type'].camelcase(:upper)).new(options[:authentication].rekey(&:to_sym))
        stems.add_listener @authenticator
      end
    end

    # @private Simplifies method calls for one-stem leaves.
    def method_missing(meth, *args) # :nodoc:
      if stems.size == 1 && stems.only.respond_to?(meth)
        stems.only.send meth, *args
      else
        super
      end
    end

    ########################## METHODS INVOKED BY STEM #########################

    # @private
    def stem_ready(_)
      return unless (@ready_mutex ||= Mutex.new).synchronize { stems.ready?.all? }
      database { startup_check }
    end

    # @private
    def irc_privmsg_event(stem, sender, arguments)
      database do
        if arguments[:channel]
          command_parse stem, sender, arguments
          did_receive_channel_message stem, sender, arguments[:channel], arguments[:message]
        else
          command_parse stem, sender, arguments if options[:respond_to_private_messages]
          did_receive_private_message stem, sender, arguments[:message]
        end
      end
    end

    # @private
    def irc_join_event(stem, sender, arguments)
      database { someone_did_join_channel stem, sender, arguments[:channel] }
    end

    # @private
    def irc_part_event(stem, sender, arguments)
      database { someone_did_leave_channel stem, sender, arguments[:channel] }
    end

    # @private
    def irc_mode_event(stem, sender, arguments)
      database do
        if arguments[:recipient]
          gained_usermodes(stem, arguments[:mode]) { |prop| someone_did_gain_usermode stem, arguments[:recipient], prop, arguments[:parameter], sender }
          lost_usermodes(stem, arguments[:mode]) { |prop| someone_did_lose_usermode stem, arguments[:recipient], prop, arguments[:parameter], sender }
        elsif arguments[:parameter] && stem.server_type.privilege_mode?(arguments[:mode])
          gained_privileges(stem, arguments[:mode]) { |prop| someone_did_gain_privilege stem, arguments[:channel], arguments[:parameter], prop, sender }
          lost_privileges(stem, arguments[:mode]) { |prop| someone_did_lose_privilege stem, arguments[:channel], arguments[:parameter], prop, sender }
        else
          gained_properties(stem, arguments[:mode]) { |prop| channel_did_gain_property stem, arguments[:channel], prop, arguments[:parameter], sender }
          lost_properties(stem, arguments[:mode]) { |prop| channel_did_lose_property stem, arguments[:channel], prop, arguments[:parameter], sender }
        end
      end
    end

    # @private
    def irc_topic_event(stem, sender, arguments)
      database { someone_did_change_topic stem, sender, arguments[:channel], arguments[:topic] }
    end

    # @private
    def irc_invite_event(stem, sender, arguments)
      database { someone_did_invite stem, sender, arguments[:recipient], arguments[:channel] }
    end

    # @private
    def irc_kick_event(stem, sender, arguments)
      database { someone_did_kick stem, sender, arguments[:channel], arguments[:recipient], arguments[:message] }
    end

    # @private
    def irc_notice_event(stem, sender, arguments)
      database do
        if arguments[:recipient]
          did_receive_notice stem, sender, arguments[:recipient], arguments[:message]
        else
          did_receive_notice stem, sender, arguments[:channel], arguments[:message]
        end
      end
    end

    # @private
    def irc_nick_event(stem, sender, arguments)
      database { nick_did_change stem, sender, arguments[:nick] }
    end

    # @private
    def irc_quit_event(stem, sender, arguments)
      database { someone_did_quit stem, sender, arguments[:message] }
    end

    ########################### OTHER PUBLIC METHODS ###########################

    # Invoked just before the leaf starts up. Override this method to do any
    # pre-startup tasks you need. The leaf is fully initialized and all methods
    # and helper objects are available.

    def will_start_up
    end

    # Performs the block in the context of a database, referenced by symbol. For
    # instance, if you had defined in `database.yml` a connection named
    # "scorekeeper", you could access that connection like so:
    #
    # ```` ruby
    # database(:scorekeeper) do
    #   # [...]
    # end
    # ````
    #
    # If your database is named after your leaf (as in the example above for a
    # leaf named "Scorekeeper"), it will automatically be set as the database
    # context for the scope of all hook, filter and command methods. However, if
    # your database connection is named differently, or if you are working in a
    # method not invoked by the Leaf class, you will need to set the connection
    # using this method.
    #
    # If you omit the `dbname` parameter, it will try to guess the name of your
    # database connection using the leaf's name and the leaf's class name.
    #
    # If the database connection cannot be found, the block is executed with no
    # database scope.
    #
    # @param [String] dbname The name of the database connection.
    # @yield A block to execute in the context of the database connection.

    def database(dbname=nil, &block)
      dbname ||= database_name
      if dbname
        repository dbname, &block
      else
        yield
      end
    end

    # @private
    #
    # Tries to guess the name of the database connection this leaf is using.
    # Looks for database connections named after either this leaf's identifier
    # or this leaf's class name. Returns nil if no suitable connection is found.

    def database_name
      return nil unless Module.constants.include?('DataMapper') || Module.constants.include?(:DataMapper)
      raise "No such database connection #{options[:database]}" if options[:database] && DataMapper::Repository.adapters[options[:database]].nil?
      # Custom database connection specified
      return options[:database].to_sym if options[:database]
      # Leaf config name
      return leaf_name.to_sym if DataMapper::Repository.adapters[leaf_name.to_sym]
      # Leaf config name, underscored
      return leaf_name.methodize.to_sym if DataMapper::Repository.adapters[leaf_name.methodize.to_sym]
      # Leaf class name
      return self.class.to_s.to_sym if DataMapper::Repository.adapters[self.class.to_s.to_sym]
      # Leaf class name, underscored
      return self.class.to_s.methodize.to_sym if DataMapper::Repository.adapters[self.class.to_s.methodize.to_sym]
      # I give up
      return nil
    end

    # @private
    def inspect
      "#<#{self.class.to_s} #{leaf_name}>"
    end

    protected

    # Duplicates a command. This method aliases the command method and also
    # ensures the correct view file is rendered if appropriate.
    #
    # @param [Symbol] old The original command name.
    # @param [Symbol] new The new command name.
    #
    # @example
    #   alias_command :google, :g

    def self.alias_command(old, new)
      raise NoMethodError, "Unknown command #{old}" unless instance_methods.include?(:"#{old}_command")
      alias_method :"#{new}_command", :"#{old}_command"
      @@view_alias[new] = old
    end

    # Adds a filter to the end of the list of filters to be run before a command
    # is executed. You can use these filters to perform tasks that prepare the
    # leaf to respond to a command, or to determine whether or not a command
    # should be run (e.g., authentication).
    #
    # Your method will be called with these parameters:
    #
    # 1. the {Stem} instance that received the command,
    # 2. the name of the channel to which the command was sent (or `nil` if it
    #    was a private message),
    # 3. the sender hash,
    # 4. the name of the command that was typed, as a symbol,
    # 5. any additional parameters after the command (same as the `msg`
    #    parameter in the `*_command` methods), and
    # 6. the custom options that were given to `before_filter`.
    #
    # If your filter returns either `nil` or `false`, the filter chain will be
    # halted and the command will not be run. For example, if you create the
    # filter:
    #
    # ```` ruby
    # before_filter :read_files, only: [ :quit, :reload ], remote_files: true
    # ````
    #
    # then any time the bot receives a "!quit" or "!reload" command, it will
    # first evaluate:
    #
    # ```` ruby
    # read_files_filter <stem>, <channel>, <sender hash>, <command>, <message>, { remote_files: true }
    # ````
    #
    # and if the result is not `false` or `nil`, the command will be executed.
    #
    # @param [Symbol] filter The name of the filter method, with `_filter`
    #   removed.
    # @param [Hash] options Additional options.
    # @option options [Symbol, Array<Symbol>] :only If set, the filter will only
    #   be run on these commands (omit `_command`).
    # @option options [Symbol, Array<Symbol>] :except If set, the filter will
    #   only be run on other than these commands (omit `_command`).

    def self.before_filter(filter, options={})
      if options[:only] && !options[:only].kind_of?(Array)
        options[:only] = [options[:only]]
      end
      if options[:except] && !options[:except].kind_of?(Array)
        options[:except] = [options[:except]]
      end
      write_inheritable_array 'before_filters', [[filter.to_sym, options]]
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
    #  after_filter :clean_tmp, only: :sendfile, remove_symlinks: true
    #
    # then any time the bot receives a "!sendfile" command, after running the
    # command it will evaluate:
    #
    #  clean_tmp_filter <stem>, <channel>, <sender hash>, :sendfile, <message>, { remove_symlinks: true }
    #
    # @param (see #before_filter)

    def self.after_filter(filter, options={})
      if options[:only] && !options[:only].kind_of?(Array)
        options[:only] = [options[:only]]
      end
      if options[:except] && !options[:except].kind_of?(Array)
        options[:except] = [options[:except]]
      end
      write_inheritable_array 'after_filters', [[filter.to_sym, options]]
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

    # Invoked when the leaf receives a private (whispered) message.
    #
    # @param [Stem] stem The stem on which the private message was received.
    # @param [Hash] sender The sender hash.
    # @param [String] msg The private message content.

    def did_receive_private_message(stem, sender, msg)
    end

    # Invoked when a message is sent to a channel the leaf is a member of (even
    # if that message was a valid command).
    #
    # @param [Stem] stem The stem on which the message was received.
    # @param [Hash] sender The sender hash.
    # @param [String] channel The name of the channel the message was sent to.
    # @param [String] msg The message content.

    def did_receive_channel_message(stem, sender, channel, msg)
    end

    # Invoked when someone joins a channel the leaf is a member of.
    #
    # @param [Stem] stem The stem with the channel.
    # @param [Hash] person The person that joined the channel (sender hash).
    # @param [String] channel The channel the person joined.

    def someone_did_join_channel(stem, person, channel)
    end

    # Invoked when someone leaves a channel the leaf is a member of.
    #
    # @param [Stem] stem The stem with the channel.
    # @param [Hash] person The person that left the channel (sender hash).
    # @param [String] channel The channel the person left.

    def someone_did_leave_channel(stem, person, channel)
    end

    # Invoked when someone gains a channel privilege.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [String] channel The channel in which the privilege was granted.
    # @param [String] nick The nickname of the person who received the
    #   privilege.
    # @param [Symbol, String] privilege The privilege that was granted. It will
    #   be a symbol (as defined in the {Daemon}, such as `:voice`), or a string
    #   if the Daemon does not define the privilege (such as "v" for voice).
    # @param [Hash] bestower The person who bestowed the privilege (sender
    #   hash).

    def someone_did_gain_privilege(stem, channel, nick, privilege, bestower)
    end

    # Invoked when someone loses a channel privilege.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [String] channel The channel in which the privilege was revoked.
    # @param [String] nick The nickname of the person who lost the privilege.
    # @param [Symbol, String] privilege The privilege that was revoked. It will
    #   be a symbol (as defined in the {Daemon}, such as `:voice`), or a string
    #   if the Daemon does not define the privilege (such as "v" for voice).
    # @param [Hash] bestower The person who revoked the privilege (sender hash).

    def someone_did_lose_privilege(stem, channel, nick, privilege, bestower)
    end

    # Invoked when a channel gains a property.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [String] channel The channel that gained the property.
    # @param [Symbol, String] property The property that was set. It will be a
    #   symbol (as defined in the {Daemon}, such as `:secret`), or a string if
    #   the Daemon does not define the privilege (such as "s" for secret).
    # @param [String] argument An additional argument for the mode, if provided.
    # @param [Hash] bestower The person who set the channel property (sender
    #   hash).

    def channel_did_gain_property(stem, channel, property, argument, bestower)
    end

    # Invoked when a channel loses a property.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [String] channel The channel that lost the property.
    # @param [Symbol, String] property The property that was removed. It will be
    #   a symbol (as defined in the {Daemon}, such as `:secret`), or a string if
    #   the Daemon does not define the privilege (such as "s" for secret).
    # @param [String] argument An additional argument for the mode, if provided.
    # @param [Hash] bestower The person who removed the channel property (sender
    #   hash).

    def channel_did_lose_property(stem, channel, property, argument, bestower)
    end

    # Invoked when someone sets a usermode on a nick.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [String] nick The nickname of the person who gained the usermode.
    # @param [Symbol, String] mode The mode that was set. It will be a symbol
    #   (as defined in the {Daemon}, such as `:invisible`), or a string if the
    #   Daemon does not define the privilege (such as "i" for invisible).
    # @param [String] argument An additional argument for the mode, if provided.
    # @param [Hash] bestower The person who set the property (sender hash).

    def someone_did_gain_usermode(stem, nick, mode, argument, bestower)
    end

    # Invoked when someone removes a usermode on a nick.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [String] nick The nickname of the person who lost the usermode.
    # @param [Symbol, String] mode The mode that was removed. It will be a
    #   symbol (as defined in the {Daemon}, such as `:invisible`), or a string
    #   if the Daemon does not define the privilege (such as "i" for invisible).
    # @param [String] argument An additional argument for the mode, if provided.
    # @param [Hash] bestower The person who removed the property (sender hash).

    def someone_did_lose_usermode(stem, nick, mode, argument, bestower)
    end

    # Invoked when someone changes a channel's topic.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [Hash] person The person who set the topic (sender hash).
    # @param [String] channel The channel who's topic was changed.
    # @param [String] topic The new topic message.

    def someone_did_change_topic(stem, person, channel, topic)
    end

    # Invoked when someone invites another person to a channel. For some IRC
    # servers, this will only be invoked if the leaf itself is invited into a
    # channel.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [Hash] inviter The person who sent the invite (sender hash).
    # @param [String] invitee The person who received the invite (nickname).
    # @param [String] channel The channel the person was invited into.

    def someone_did_invite(stem, inviter, invitee, channel)
    end

    # Invoked when someone is kicked from a channel. Note that this is called
    # when your leaf is kicked as well, so it may well be the case that
    # `channel` is a channel you are no longer in!
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [Hash] kicker The person who gave the boot (sender hash).
    # @param [String] channel The channel the person was kicked from.
    # @param [String] victim The person who got the boot (nickname).
    # @param [String] msg The message accompanying the kick.

    def someone_did_kick(stem, kicker, channel, victim, msg)
    end

    # Invoked when a notice is received. Notices are like channel or private
    # messages, except that leaves are expected _not_ to respond to them.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [Hash] sender The person who sent the notice (sender hash).
    # @param [String] recipient The channel or nickname that received the
    #   notice.
    # @param [String] msg The notice message.

    def did_receive_notice(stem, sender, recipient, msg)
    end

    # Invoked when a user changes his nick.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [Hash] person The person who changed their nick (including his/her
    #   old nick).
    # @param [String] nick The person's new nick.

    def nick_did_change(stem, person, nick)
    end

    # Invoked when someone quits IRC.
    #
    # @param [Stem] stem The stem on which the event occurred.
    # @param [Hash] person The person who quit (sender hash).
    # @param [String] msg The quit message.

    def someone_did_quit(stem, person, msg)
    end

    # @private
    UNADVERTISED_COMMANDS = %w(about commands)

    # Typing this command displays a list of all commands for each leaf running
    # off this stem.

    def commands_command(stem, sender, reply_to, msg)
      commands = self.class.instance_methods.select { |m| m =~ /^\w+_command$/ }
      commands.map! { |m| m.to_s.match(/^(\w+)_command$/)[1] }
      commands.reject! { |m| UNADVERTISED_COMMANDS.include? m }
      return if commands.empty?
      commands.map! { |c| "#{options[:command_prefix]}#{c}" }
      "Commands for #{leaf_name}: #{commands.sort.join(', ')}"
    end

    # Sets a custom view name to render. The name doesn't have to correspond to
    # an actual command, just an existing view file. Example:
    #
    # ```` ruby
    # def my_command(stem, sender, reply_to, msg)
    #   render :help and return if msg.empty? # user doesn't know how to use the command
    #   # [...]
    # end
    # ````
    #
    # Only one view is rendered per command. If this method is called multiple
    # times, an exception is raised. This method has no effect outside of a
    # `*_command` method.
    #
    # By default, the view named after the command will be rendered. If no such
    # view exists, the value returned by the method will be used as the
    # response.
    #
    # @param [Symbol] view A view name.
    # @raise [StandardError] If called more than once per command.

    def render(view)
      # Since only one command is executed per thread, we can store the view to
      # render as a thread-local variable.
      raise "The render method should be called at most once per command" if Thread.current[:render_view]
      Thread.current[:render_view] = view.to_s
      return nil
    end

    # Gets or sets a variable for use in the view. Use this method in
    # `*_command` methods to pass data to the view ERb file, and in the ERb file
    # to retrieve these values. For example, in your `controller.rb` file:
    #
    # ```` ruby
    # def my_command(stem, sender, reply_to, msg)
    #   var num_lights: 4
    # end
    # ````
    #
    # And in your `my.txt.erb` file:
    #
    # ```` erb
    # THERE ARE <%= var :num_lights %> LIGHTS!
    # ````
    #
    # @overload vars(var)
    #   Retrieves a stored value.
    #   @param [Symbol] var The value name.
    #   @return The value.
    #
    # @overload vars(values)
    #   @param [Hash<Symbol, Object>] values A hash mapping var names to the
    #     values to set for those vars.

    def var(vars)
      return Thread.current[:vars][vars] if vars.kind_of? Symbol
      return vars.each { |var, val| Thread.current[:vars][var] = val } if vars.kind_of? Hash
      raise ArgumentError, "var must take a symbol or a hash"
    end

    private

    def startup_check
      return if @started_up
      @started_up = true
      did_start_up
    end

    def command_parse(stem, sender, arguments)
      if arguments[:channel] || options[:respond_to_private_messages]
        reply_to = arguments[:channel] ? arguments[:channel] : sender[:nick]
        matches  = arguments[:message].match(/^#{Regexp.escape options[:command_prefix]}(\w+)\s*(.*)$/)
        if matches
          name   = matches[1].to_sym
          msg    = matches[2]
          command_exec name, stem, arguments[:channel], sender, msg, reply_to
        end
      end
    end

    def command_exec(name, stem, channel, sender, msg, reply_to)
      cmd_sym = "#{name}_command".to_sym
      return unless respond_to? cmd_sym
      msg = msg.presence

      return unless authenticated?(name, stem, channel, sender)
      return unless run_before_filters(name, stem, channel, sender, name, msg)

      Thread.current[:vars] = Hash.new
      return_val            = send(cmd_sym, stem, sender, reply_to, msg)
      view                  = Thread.current[:render_view]
      view                  ||= @@view_alias[name]
      if return_val.kind_of? String
        stem.message return_val, reply_to
      elsif options[:views][view.to_s]
        stem.message parse_view(view.to_s), reply_to
      #else
      #  raise "You must either specify a view to render or return a string to send."
      end
      Thread.current[:vars]        = nil
      Thread.current[:render_view] = nil # Clear it out in case the command is synchronized
      run_after_filters name, stem, channel, sender, name, msg
    end

    def parse_view(name)
      return nil unless options[:views][name]
      ERB.new(options[:views][name]).result(binding)
    end

    def leaf_name
      Foliater.instance.leaves.key self
    end

    def run_before_filters(cmd, stem, channel, sender, _, msg)
      command = cmd.to_sym
      self.class.before_filters.each do |filter, options|
        local_opts = options.dup
        next if local_opts[:only] && !local_opts.delete(:only).include?(command)
        next if local_opts[:except] && local_opts.delete(:except).include?(command)
        return false unless method("#{filter}_filter")[stem, channel, sender, command, msg, local_opts]
      end
      return true
    end

    def run_after_filters(cmd, stem, channel, sender, _, msg)
      command = cmd.to_sym
      self.class.after_filters.each do |filter, options|
        local_opts = options.dup
        next if local_opts[:only] && !local_opts.delete(:only).include?(command)
        next if local_opts[:except] && local_opts.delete(:except).include?(command)
        method("#{filter}_filter")[stem, channel, sender, command, msg, local_opts]
      end
    end

    def authenticated?(cmd, stem, channel, sender)
      return true if @authenticator.nil?
      # Any method annotated as protected is authenticated unconditionally
      return true unless self.class.ann("#{cmd}_command".to_sym, :protected)
      if @authenticator.authenticate(stem, channel, sender, self)
        return true
      else
        stem.message @authenticator.unauthorized, channel unless options[:authentication]['silent']
        return false
      end
    end

    def gained_privileges(stem, privstr)
      return unless privstr[0, 1] == '+'
      privstr.except_first.each_char { |c| yield stem.server_type.privilege[c] }
    end

    def lost_privileges(stem, privstr)
      return unless privstr[0, 1] == '-'
      privstr.except_first.each_char { |c| yield stem.server_type.privilege[c] }
    end

    def gained_properties(stem, propstr)
      return unless propstr[0, 1] == '+'
      propstr.except_first.each_char { |c| yield stem.server_type.channel_mode[c] }
    end

    def lost_properties(stem, propstr)
      return unless propstr[0, 1] == '-'
      propstr.except_first.each_char { |c| yield stem.server_type.channel_mode[c] }
    end

    def gained_usermodes(stem, modestr)
      return unless modestr[0, 1] == '+'
      modestr.except_first.each_char { |c| yield stem.server_type.usermode[c] }
    end

    def lost_usermodes(stem, modestr)
      return unless modestr[0, 1] == '-'
      modestr.except_first.each_char { |c| yield stem.server_type.usermode[c] }
    end

    def self.before_filters
      read_inheritable_attribute('before_filters') || []
    end

    def self.after_filters
      read_inheritable_attribute('after_filters') || []
    end
  end
end
