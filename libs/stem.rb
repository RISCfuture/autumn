# Defines the Autumn::Stem class, an IRC client library.

require 'thread'
require 'socket'
require 'openssl'

module Autumn
  
  # A connection to an IRC server. The stem acts as the IRC client on which a
  # Leaf runs. It receives messages from the IRC server and sends messages to
  # the server. Stem is compatible with many IRC daemons; details of the IRC
  # protocol are handled by a Daemon instance. (See "Compatibility with
  # Different Server Types," below).
  #
  # Generally stems are initialized by the Foliater, but should you want to
  # instantiate one yourself, a Stem is instantiated with a server to connect to
  # and a nickname to acquire (see the initialize method docs). Once you
  # initialize a Stem, you should call add_listener one or more times to
  # indicate to the stem what objects are interested in working with it.
  #
  # = Listeners and Listener Plug-Ins
  #
  # An object that functions as a listener should conform to an implicit
  # protocol. See the add_listener docs for more infortmation on what methods
  # you can implement to listen for IRC events. Duck typing is used -- you need
  # not implement every method of the protocol, only those you are concerned
  # with.
  #
  # Listeners can also act as plugins: Such listeners add functionality to
  # other listeners (for example, a CTCP listener that adds CTCP support to
  # other listeners, such as a Leaf instance). For more information, see the
  # add_listener docs.
  #
  # = Starting the IRC Session
  #
  # Once you have finished configuring your stem and you are ready to begin the
  # IRC session, call the start method. This method blocks until the the socket
  # has been closed, so it should be run in a thread. Once the connection has
  # been made, you are free to send and receive IRC commands until you close the
  # connection, which is done with the quit method.
  #
  # = Receiving and Sending IRC Commands
  #
  # Receiving events is explained in the add_listener docs. To send an IRC
  # command, simply call a method named after the command name. For instance, if
  # you wish to PRIVMSG another nick, call the +privmsg+ method. If you wish to
  # JOIN a channel, call the +join+ method. The parameters should be specified
  # in the same order as the IRC command expects.
  #
  # For more information on what IRC commands are "method-ized", see the
  # +IRC_COMMANDS+ constant. For more information on the proper way to use these
  # commands (and thus, the methods that call them), consult the Daemon class.
  #
  # = Compatibility with Different Server Types
  #
  # Many different IRC server daemons exist, and each one has a slightly
  # different IRC implementation. To manage this, there is an option called
  # +server_type+, which is set automatically by the stem if it can determine
  # the IRC software that the server is running. Server types are instances of
  # the Daemon class, and are associated with a name. A stem's server type
  # affects things like response codes, user modes, and channel modes, as these
  # vary from server to server.
  #
  # If the stem is unsure what IRC daemon your server is running, it will use
  # the default Daemon instance. This default server type will be compatible
  # with nearly every server out there. You may not be able to leverage some of
  # the more esoteric IRC features of your particular server, but for the most
  # common uses of IRC (sending and receiving messages, for example), it will
  # suffice.
  #
  # If you'd like to manually specify a server type, you can pass its name for
  # the +server_type+ initialization option. Consult the resources/daemons
  # directory for valid Daemon names and hints on how to make your own Daemon
  # specification, should you desire.
  #
  # = Channel Names
  #
  # The convention for Autumn channel names is: When you specify a channel to
  # an Autumn stem, you can (but don't have to) prefix it with the '#'
  # character, if it's a normal IRC channel. When an Autumn stem gives a channel
  # name to you, it will always start with the '#' character (assuming it's a
  # normal IRC channel, of course). If your channel is prefixed with a different
  # character (say, '&'), you will need to include that prefix every time you
  # pass a channel name to a stem method.
  #
  # So, if you would like your stem to send a message to the "##kittens"
  # channel, you can omit the '#' character; but if it's a server-local channel
  # called "&kittens", you will have to provide the '&' character. Likewise, if
  # you are overriding a hook method, you can be guaranteed that the channel
  # given to you will always be called "##kittens", and not "kittens".
  #
  # = Synchronous Methods
  #
  # Because new messages are received and processed in separate threads, methods
  # can sometimes receive messages out of order (for instance, if a first
  # message takes a long time to process and a second message takes a short time
  # to process). In the event that you require a guarantee that your method will
  # receive messages in order, and that it will only be invoked in a single
  # thread, annotate your method with the +stem_sync+ property.
  #
  # For instance, you might want to ensure that you are finished processing 353
  # messages (replies to NAMES commands) before you tackle 366 messages (end of
  # NAMES list). To ensure these methods are invoked in the correct order:
  #
  #  class MyListener
  #    def irc_rpl_namreply_response(stem, sender, recipient, arguments, msg)
  #      [...]
  #    end
  #    
  #    def irc_rpl_endofnames_response(stem, sender, recipient, arguments, msg)
  #      [...]
  #    end
  #    
  #    ann :irc_rpl_namreply_response, :stem_sync => true
  #    ann :irc_rpl_endofnames_response, :stem_sync => true
  #  end
  #
  # All such methods will be run in a single thread, and will receive server
  # messages in order. Because of this, it is important that synchronized
  # methods do not spend a lot of time processing a single message, as it forces
  # all other synchronous methods to wait their turn.
  #
  # This annotation is only relevant to "invoked" methods, those methods in
  # listeners that are invoked by the stem's broadcast method. Methods that are
  # marked with this annotation will also run faster, because they don't have
  # the overhead of setting up a new thread.
  #
  # Many of Stem's own internal methods are synchronized, to ensure internal
  # data such as the channels list and channel members list stays consistent.
  # Because of this, any method marked as synchronized can be guaranteed that
  # the stem's channel data is consistent and "in sync" for the moment of time
  # that the message was received.
  #
  # = Throttling
  #
  # If you send a message with the +privmsg+ command, it will not be throttled.
  # (Most IRC servers have some form of flood control that throttles rapid
  # privmsg commands, however.)
  #
  # If your IRC server does not have flood control, or you want to use
  # client-side flood control, you can enable the +throttling+ option. The stem
  # will throttle large numbers of simultaneous messages, sending them with
  # short pauses in between.
  #
  # The +privmsg+ command will still _not_ be throttled (since it is a facade
  # for the pure IRC command), but the StemFacade#message command will gain the
  # ability to throttle its messages.
  #
  # By default, the stem will begin throttling when there are five or more
  # messages queued to be sent. It will continue throttling until the queue is
  # emptied. When throttling, messages will be sent with a delay of one second
  # between them. These options can be customized (see the initialize method
  # options).

  class Stem
    include StemFacade
    include Anise::Annotation
    
    # Describes all possible channel names. Omits the channel prefix, as that
    # can vary from server to server. (See channel?)
    CHANNEL_REGEX = "[^\\s\\x7,:]+"
    # The default regular expression for IRC nicknames.
    NICK_REGEX = "[a-zA-Z][a-zA-Z0-9\\-_\\[\\]\\{\\}\\\\|`\\^]+"
  
    # A parameter in an IRC command.
  
    class Parameter # :nodoc:
      attr :name
      attr :required
      attr :colonize
      attr :list
    
      def initialize(newname, options={})
        @name = newname
        @required = options[:required] or true
        @colonize = options[:colonize] or false
        @list = options[:list] or false
      end
    end
  
    def self.param(name, opts={}) # :nodoc:
      Parameter.new(name, opts)
    end
  
    # Valid IRC command names, mapped to information about their parameters.
    IRC_COMMANDS = {
      :pass => [ param('password') ],
      :nick => [ param('nickname') ],
      :user => [ param('user'), param('host'), param('server'), param('name') ],
      :oper => [ param('user'), param('password') ],
      :quit => [ param('message', :required => false, :colonize => true) ],
    
      :join => [ param('channels', :list => true), param('keys', :list => true) ],
      :part => [ param('channels', :list => true) ],
      :mode => [ param('channel/nick'), param('mode'), param('limit', :required => false), param('user', :required => false), param('mask', :required => false) ],
      :topic => [ param('channel'), param('topic', :required => false, :colonize => true) ],
      :names => [ param('channels', :required => false, :list => true) ],
      :list => [ param('channels', :required => false, :list => true), param('server', :required => false) ],
      :invite => [ param('nick'), param('channel') ],
      :kick => [ param('channels', :list => true), param('users', :list => true), param('comment', :required => false, :colonize => true) ],
    
      :version => [ param('server', :required => false) ],
      :stats => [ param('query', :required => false), param('server', :required => false) ],
      :links => [ param('server/mask', :required => false), param('server/mask', :required => false) ],
      :time => [ param('server', :required => false) ],
      :connect => [ param('target server'), param('port', :required => false), param('remote server', :required => false) ],
      :trace => [ param('server', :required => false) ],
      :admin => [ param('server', :required => false) ],
      :info => [ param('server', :required => false) ],
    
      :privmsg => [ param('receivers', :list => true), param('message', :colonize => true) ],
      :notice => [ param('nick'), param('message', :colonize => true) ],
    
      :who => [ param('name', :required => false), param('is mask', :required => false) ],
      :whois => [ param('server/nicks', :list => true), param('nicks', :list => true, :required => false) ],
      :whowas => [ param('nick'), param('history count', :required => false), param('server', :required => false) ],
    
      :pong => [ param('code', :required => false, :colonize => true) ]
    }
    
    # The address of the server this stem is connected to.
    attr :server
    # The remote port that this stem is connecting to.
    attr :port
    # The local IP to bind to (virtual hosting).
    attr :local_ip
    # The global configuration options plus those for the current season and
    # this stem.
    attr :options
    # The channels that this stem is a member of.
    attr :channels
    # The LogFacade instance handling this stem.
    attr :logger
    # A Proc that will be called if a nickname is in use. It should take one
    # argument, the nickname that was unavailable, and return a new nickname to
    # try. The default Proc appends an underscore to the nickname to produce a
    # new one, or GHOSTs the nick if possible. This block should return nil if
    # you do not want another NICK attempt to be made.
    attr :nick_generator
    # The Daemon instance that describes the IRC server this client is connected
    # to.
    attr :server_type
    # A hash of channel members by channel name.
    attr :channel_members
    
    # Creates an instance that connects to a given IRC server and requests a
    # given nick. Valid options:
    #
    # +port+:: The port that the IRC client should connect on (default 6667).
    # +local_ip+:: Set this if you want to bind to an IP other than your default
    #              (for virtual hosting).
    # +logger+:: Specifies a logger instance to use. If none is specified, a new
    #            LogFacade instance is created for the current season.
    # +ssl+:: If true, indicates that the connection will be made over SSL.
    # +user+:: The username to transmit to the IRC server (by default it's the
    #          user's nick).
    # +name+:: The real name to transmit to the IRC server (by default it's the
    #          user's nick).
    # +server_password+:: The server password (not the nick password), if
    #                     necessary.
    # +password+:: The password to send to NickServ, if your leaf's nick is
    #              registered.
    # +channel+:: The name of a channel to join.
    # +channels+:: An array of channel names to join.
    # +sever_type+:: The name of the server type. (See Daemon). If left blank,
    #                the default Daemon instance is used.
    # +rejoin+:: If true, the stem will rejoin a channel it is kicked from.
    # +case_sensitive_channel_names+:: If true, indicates to the IRC client that
    #                                  this IRC server uses case-sensitive
    #                                  channel names.
    # +dont_ghost+:: If true, does not issue a /ghost command if the stem's nick
    #                is taken. (This is only relevant if the nick is registered
    #                and +password+ is specified.) <b>You should use this on IRC
    #                servers that don't use "NickServ" -- otherwise someone may
    #                change their nick to NickServ and discover your
    #                password!</b>
    # +ghost_without_password+:: Set this to true if your IRC server uses
    #                            hostname authentication instead of password
    #                            authentication for GHOST commands.
    # +throttle+:: If enabled, the stem will throttle large amounts of
    #              simultaneous messages.
    # +throttle_rate+:: Sets the number of seconds that pass between consecutive
    #                   PRIVMSG's when the leaf's output is throttled.
    # +throttle_threshold+:: Sets the number of simultaneous messages that must
    #                        be queued before the leaf begins throttling output.
    #
    # Any channel name can be a one-item hash, in which case it is taken to be
    # a channel name-channel password association.
  
    def initialize(server, newnick, opts)
      raise ArgumentError, "Please specify at least one channel" unless opts[:channel] or opts[:channels]
      
      @nick = newnick
      @server = server
      @port = opts[:port]
      @port ||= 6667
      @local_ip = opts[:local_ip]
      @options = opts
      @listeners = Set.new
      @listeners << self
      @logger = @options[:logger]
      @nick_generator = Proc.new do |oldnick|
        if options[:ghost_without_password] then
          message "GHOST #{oldnick}", 'NickServ'
          nil
        elsif options[:dont_ghost] or options[:password].nil? then
          "#{oldnick}_"
        else
          message "GHOST #{oldnick} #{options[:password]}", 'NickServ'
          nil
        end
      end
      @server_type = Daemon[opts[:server_type]]
      @server_type ||= Daemon.default
      @throttle_rate = opts[:throttle_rate]
      @throttle_rate ||= 1
      @throttle_threshold = opts[:throttle_threshold]
      @throttle_threshold ||= 5
      
      @nick_regex = (opts[:nick_regex] ? opts[:nick_regex].to_re : NICK_REGEX)
      
      @channels = Set.new
      @channels.merge opts[:channels] if opts[:channels]
      @channels << opts[:channel] if opts[:channel]
      @channels.map! do |chan|
        if chan.kind_of? Hash then
          { normalized_channel_name(chan.keys.only) => chan.values.only }
        else
          normalized_channel_name chan
        end
      end
      # Make a hash of channels to their passwords
      @channel_passwords = @channels.select { |ch| ch.kind_of? Hash }.mash { |pair| pair }
      # Strip the passwords from @channels, making it an array of channel names only
      @channels.map! { |chan| chan.kind_of?(Hash) ? chan.keys.only : chan }
      @channel_members = Hash.new
      @updating_channel_members = Hash.new # stores the NAMES list as its being built
      
      if @throttle = opts[:throttle] then
        @messages_queue = Queue.new
        @messages_thread = Thread.new do
          throttled = false
          loop do
            args = @messages_queue.pop
            throttled = true if not throttled and @messages_queue.length >= @throttle_threshold
            throttled = false if throttled and @messages_queue.empty?
            sleep @throttle_rate if throttled
            privmsg *args
          end
        end
      end
      
      @chan_mutex = Mutex.new
      @join_mutex = Mutex.new
      @socket_mutex = Mutex.new
    end
    
    # Adds an object that will receive notifications of incoming IRC messages.
    # For each IRC event that the listener is interested in, the listener should
    # implement a method in the form <tt>irc_[event]_event</tt>, where [event]
    # is the name of the event, as taken from the +IRC_COMMANDS+ hash. For
    # example, to register interest in PRIVMSG events, implement the method:
    #
    #  irc_privmsg_event(stem, sender, arguments)
    #
    # If you wish to perform an operation each time any IRC event is received,
    # you can implement the method:
    #
    #  irc_event(stem, command, sender, arguments)
    #
    # The parameters for both methods are as follows:
    #
    # +stem+:: This Stem instance.
    # +sender+:: A sender hash (see the Leaf docs).
    # +arguments+:: A hash whose keys depend on the IRC command. Keys can be,
    #               for example, <tt>:recipient</tt>, <tt>:channel</tt>,
    #               <tt>:mode</tt>, or <tt>:message</tt>. Any can be nil.
    #
    # The +irc_event+ method also receives the command name as a symbol.
    #
    # In addition to events, the Stem will also pass IRC server responses along
    # to its listeners. Known responses (those specified by the Daemon) are
    # translated to programmer-friendly symbols using the Daemon.event hash. The
    # rest are left in numerical form.
    #
    # If you wish to register interest in a response code, implement a method of
    # the form <tt>irc_[response]_response</tt>, where [response] is the symbol
    # or numerical form of the response. For instance, to register interest in
    # channel-full errors, you'd implement:
    #
    #  irc_err_channelisfull_response(stem, sender, recipient, arguments, msg)
    #
    # You can also register an interest in all server responses by implementing:
    #
    #  irc_response(stem, response, sender, recipient, arguments, msg)
    #
    # This method is invoked when the server sends a response message. The
    # parameters for both methods are:
    #
    # +sender+:: The server's address.
    # +recipient+:: The nick of the recipient (sometimes "*" if no nick has been
    #               assigned yet).
    # +arguments+:: Array of response arguments, as strings.
    # +message+:: An additional message attached to the end of the response.
    #
    # The +irc_server_response+ method additionally receives the response code
    # as a symbol or numerical parameter.
    #
    # Please note that there are hundreds of possible responses, and IRC servers
    # differ in what information they send along with each response code. I
    # recommend inspecting the output of the specific IRC server you are working
    # with, so you know what arguments to expect.
    #
    # If your listener is interested in IRC server notices, implement the
    # method:
    #
    #  irc_server_notice(stem, server, sender, msg)
    #
    # This method will be invoked for notices from the IRC server. Its
    # parameters are:
    #
    # +server+:: The server's address.
    # +sender+:: The message originator (e.g., "Auth" for authentication-related
    #            messages).
    # +msg+:: The notice.
    #
    # If your listener is interested in IRC server errors, implement the method:
    #
    #  irc_server_error(stem, msg)
    #
    # This method will be invoked whenever an IRC server reports an error, and
    # is passed the error message. Server errors differ from normal server
    # responses, which themselves can sometimes indicate errors.
    #
    # Some listeners can act as listener plugins; see the broadcast method for
    # more information.
    #
    # If you'd like your listener to perform actions after it's been added to a
    # Stem, implement a method called +added+. This method will be called when
    # the listener is added to a stem, and will be passed the Stem instance it
    # was added to. You can use this method, for instance, to add additional
    # methods to the stem.
    #
    # Your listener can implement the +stem_ready+ method, which will be called
    # once the stem has started up, connected to the server, and joined all its
    # channels. This method is passed the stem instance.
  
    def add_listener(obj)
      @listeners << obj
      obj.class.extend Anise::Annotation # give it the ability to sync
      obj.respond :added, self
    end
    
    # Sends the method with the name +meth+ (a symbol) to all listeners that
    # respond to that method. You can optionally specify one or more arguments.
    # This method is meant for use by <b>listener plugins</b>: listeners that
    # add features to other listeners by allowing them to implement optional
    # methods.
    #
    # For example, you might have a listener plugin that adds CTCP support to
    # stems. Such a method would parse incoming messages for CTCP commands, and
    # then use the broadcast method to call methods named after those commands.
    # Other listeners who want to use CTCP support can implement the methods
    # that your listener plugin broadcasts.
    #
    # <b>Note:</b> Each method call will be executed in its own thread, and all
    # exceptions will be caught and reported. This method will only invoke
    # listener methods that have _not_ been marked as synchronized. (See
    # "Synchronous Methods" in the class docs.)
    
    def broadcast(meth, *args)
      @listeners.select { |listener| not listener.class.ann(meth, :stem_sync) }.each do |listener|
        Thread.new do
          begin
            listener.respond meth, *args
          rescue Exception
            options[:logger].error $!
            message("Listener #{listener.class.to_s} raised an exception responding to #{meth}: " + $!.to_s) rescue nil # Try to report the error if possible
          end
        end
      end
    end
    
    # Same as the broadcast method, but only invokes listener methods that
    # _have_ been marked as synchronized.
    
    def broadcast_sync(meth, *args)
      @listeners.select { |listener| listener.class.ann(meth, :stem_sync) }.each { |listener| listener.respond meth, *args }
    end
  
    # Opens a connection to the IRC server and begins listening on it. This
    # method runs until the socket is closed, and should be run in a thread. It
    # will terminate when the connection is closed. No messages should be
    # transmitted, nor will messages be received, until this method is called.
    #
    # In the event that the nick is unavailable, the +nick_generator+ proc will
    # be called.
  
    def start
      # Synchronous (mutual exclusion) message processing is handled by a
      # producer-consumer approach. The socket pushes messages onto this queue,
      # which are processed by a consumer thread one at a time.
      @messages = Queue.new
      @message_consumer = Thread.new do
        loop do
          meths = @messages.pop
          begin
            meths.each { |meth, args| broadcast_sync meth, *args }
          rescue
            options[:logger].error $!
          end
        end
      end
      
      @socket = connect
      username = @options[:user]
      username ||= @nick
      realname = @options[:name]
      realname ||= @nick
    
      pass @options[:server_password] if @options[:server_password]
      user username, @nick, @nick, realname
      nick @nick
      
      while line = @socket.gets
        meths = receive line # parse the line and get a list of methods to call
        @messages.push meths # push the methods on the queue; the consumer thread will execute all the synchronous methods
        # then execute all the other methods in their own thread
        meths.each { |meth, args| broadcast meth, *args }
      end
    end
    
    # Returns true if this stem has started up completely, connected to the IRC
    # server, and joined all its channels. A period of 10 seconds is allowed to
    # join all channels, after which the stem will report ready even if some
    # channels could not be joined.
    
    def ready?
      @ready == true
    end
    
    # Normalizes a channel name by placing a "#" character before the name if no
    # channel prefix is otherwise present. Also converts the name to lowercase
    # if the +case_sensitive_channel_names+ option is false. You can suppress
    # the automatic prefixing by passing false for +add_prefix+.
    
    def normalized_channel_name(channel, add_prefix=true)
      norm_chan = channel.dup
      norm_chan.downcase! unless options[:case_sensitive_channel_names]
      norm_chan = "##{norm_chan}" unless server_type.channel_prefix?(channel[0,1]) or not add_prefix
      return norm_chan
    end
  
    def method_missing(meth, *args) # :nodoc:
      if IRC_COMMANDS.include? meth then
        param_info = IRC_COMMANDS[meth]
        params = Array.new
        param_info.each do |param|
          raise ArgumentError, "#{param.name} is required" if args.empty? and param.required
          arg = args.shift
          next if arg.nil? or arg.empty?
          arg = (param.list and arg.kind_of? Array) ? arg.map(&:to_s).join(',') : arg.to_s
          arg = ":#{arg}" if param.colonize
          params << arg
        end
        raise ArgumentError, "Too many parameters" unless args.empty?
        transmit "#{meth.to_s.upcase} #{params.join(' ')}"
      else
        super
      end
    end
    
    # Given a full channel name, returns the channel type as a symbol. Values
    # can be found in the Daemons instance. Returns <tt>:unknown</tt> for
    # unknown channel types.
    
    def channel_type(channel)
      type = server_type.channel_prefix[channel[0,1]]
      type ? type : :unknown
    end
    
    # Returns true if the string appears to be a channel name.
    
    def channel?(str)
      prefixes = Regexp.escape(server_type.channel_prefix.keys.join)
      str.match("[#{prefixes}]#{CHANNEL_REGEX}") != nil
    end
    
    # Returns true if the string appears to be a nickname.
    
    def nick?(str)
      str.match(@nick_regex) != nil
    end

    # Returns the nick this stem is using.

    def nickname
      @nick
    end
    
    def inspect # :nodoc:
      "#<#{self.class.to_s} #{server}:#{port}>"
    end
  
    protected
    
    def irc_ping_event(stem, sender, arguments) # :nodoc:
      arguments[:message].nil? ? pong : pong(arguments[:message])
    end
    ann :irc_ping_event, :stem_sync => true # To avoid overhead of a whole new thread just for a pong
    
    def irc_rpl_yourhost_response(stem, sender, recipient, arguments, msg) # :nodoc:
      return if options[:server_type]
      type = nil
      Daemon.each_name do |name|
        next unless msg.include? name
        if type then
          logger.info "Ambiguous server type; could be #{type} or #{name}"
          return
        else
          type = name
        end
      end
      return unless type
      @server_type = Daemon[type] 
      logger.info "Auto-detected #{type} server daemon type"
    end
    ann :irc_rpl_yourhost_response, :stem_sync => true # So methods that synchronize can be guaranteed the host is known ASAP
    
    def irc_err_nicknameinuse_response(stem, sender, recipient, arguments, msg) # :nodoc:
      return unless nick_generator
      newnick = nick_generator.call(arguments[0])
      nick newnick if newnick
    end
    
    def irc_rpl_endofmotd_response(stem, sender, recipient, arguments, msg) # :nodoc:
      post_startup
    end
    
    def irc_err_nomotd_response(stem, sender, recipient, arguments, msg) # :nodoc:
      post_startup
    end
    
    def irc_rpl_namreply_response(stem, sender, recipient, arguments, msg) # :nodoc:
      update_names_list normalized_channel_name(arguments[1]), msg.words unless arguments[1] == "*" # "*" refers to users not on a channel
    end
    ann :irc_rpl_namreply_response, :stem_sync => true # So endofnames isn't processed before namreply
    
    def irc_rpl_endofnames_response(stem, sender, recipient, arguments, msg) # :nodoc:
      finish_names_list_update normalized_channel_name(arguments[0])
    end
    ann :irc_rpl_endofnames_response, :stem_sync => true # so endofnames isn't processed before namreply
    
    def irc_kick_event(stem, sender, arguments) # :nodoc:
      if arguments[:recipient] == @nick then
        old_pass = @channel_passwords[arguments[:channel]]
        @chan_mutex.synchronize do
          drop_channel arguments[:channel]
          #TODO what should we do if we are in the middle of receiving NAMES replies?
        end
        join_channel arguments[:channel], old_pass if options[:rejoin]
      else
        @chan_mutex.synchronize do
          @channel_members[arguments[:channel]].delete arguments[:recipient]
          #TODO what should we do if we are in the middle of receiving NAMES replies?
        end
      end
    end
    ann :irc_kick_event, :stem_sync => true # So methods that synchronize can be guaranteed the channel variables are up to date
    
    def irc_mode_event(stem, sender, arguments) # :nodoc:
      names arguments[:channel] if arguments[:parameter] and server_type.privilege_mode?(arguments[:mode])
    end
    ann :irc_mode_event, :stem_sync => true # To avoid overhead of a whole new thread for a names reply
    
    def irc_join_event(stem, sender, arguments) # :nodoc:
      if sender[:nick] == @nick then
        should_broadcast = false
        @chan_mutex.synchronize do
          @channels << arguments[:channel]
          @channel_members[arguments[:channel]] ||= Hash.new
          @channel_members[arguments[:channel]][sender[:nick]] = :unvoiced
          #TODO what should we do if we are in the middle of receiving NAMES replies?
          #TODO can we assume that all new channel members are unvoiced?
        end
        @join_mutex.synchronize do
          if @channels_to_join then
            @channels_to_join.delete arguments[:channel]
            if @channels_to_join.empty? then
              should_broadcast = true unless @ready
              @ready = true
              @channels_to_join = nil
            end
          end
        end
        # The ready_thread is also looking to set ready to true and broadcast,
        # so to prevent us both from doing it, we enter a critical section and
        # record whether the broadcast has been made already. We set @ready to
        # true and record if it was already set to true. If it wasn't already
        # set to true, we know the broadcast hasn't gone out, so we send it out.
        broadcast :stem_ready, self if should_broadcast
      else
        @chan_mutex.synchronize do
          @channel_members[arguments[:channel]][sender[:nick]] = :unvoiced
          #TODO what should we do if we are in the middle of receiving NAMES replies?
          #TODO can we assume that all new channel members are unvoiced?
        end
      end
    end
    ann :irc_join_event, :stem_sync => true # So methods that synchronize can be guaranteed the channel variables are up to date
    
    def irc_part_event(stem, sender, arguments) # :nodoc:
      @chan_mutex.synchronize do
        if sender[:nick] == @nick then
          drop_channel arguments[:channel]
        else
          @channel_members[arguments[:channel]].delete sender[:nick]
        end
        #TODO what should we do if we are in the middle of receiving NAMES replies?
      end
    end
    ann :irc_part_event, :stem_sync => true # So methods that synchronize can be guaranteed the channel variables are up to date
    
    def irc_nick_event(stem, sender, arguments) # :nodoc:
      @nick = arguments[:nick] if sender[:nick] == @nick
      @chan_mutex.synchronize do
        @channel_members.each { |chan, members| members[arguments[:nick]] = members.delete(sender[:nick]) }
        #TODO what should we do if we are in the middle of receiving NAMES replies?
      end
    end
    ann :irc_nick_event, :stem_sync => true # So methods that synchronize can be guaranteed the channel variables are up to date

    def irc_quit_event(stem, sender, arguments) # :nodoc:
      @chan_mutex.synchronize do
        @channel_members.each { |chan, members| members.delete sender[:nick] }
        #TODO what should we do if we are in the middle of receiving NAMES replies?
      end
    end
    ann :irc_quit_event, :stem_sync => true # So methods that synchronize can be guaranteed the channel variables are up to date
    
    private
  
    def connect
      logger.debug "Connecting to #{@server}:#{@port}..."
      socket = TCPSocket.new @server, @port, @local_ip
      return socket unless options[:ssl]
      ssl_context = OpenSSL::SSL::SSLContext.new
      unless ssl_context.verify_mode
        logger.warn "SSL - Peer certificate won't be verified this session."
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      ssl_socket.sync_close = true
      ssl_socket.connect
      return ssl_socket
    end
  
    def transmit(comm)
      @socket_mutex.synchronize do
        raise "IRC connection not opened yet" unless @socket
        logger.debug ">> " + comm
        @socket.puts comm
      end
    end
  
    # Parses a message and returns a hash of methods to their arguments
    def receive(comm)
      meths = Hash.new
      logger.debug "<< " + comm
    
      if comm =~ /^:(.+?)\s+NOTICE\s+(\S+)\s+:(.+?)[\r\n]*$/
        server, sender, msg = $1, $2, $3
        meths[:irc_server_notice] = [ self, server, sender, msg ]
        return meths
      elsif comm =~ /^NOTICE\s+(.+?)\s+:(.+?)[\r\n]*$/
        sender, msg = $1, $2
        meths[:irc_server_notice] = [ self, nil, sender, msg ]
        return meths
      elsif comm =~ /^ERROR :(.+?)[\r\n]*$/ then
        msg = $1
        meths[:irc_server_error] = [ self, msg ]
        return meths
      elsif comm =~ /^:(#{@nick_regex})!(\S+?)@(\S+?)\s+([A-Z]+)\s+(.*?)[\r\n]*$/ then
        sender = { :nick => $1, :user => $2, :host => $3 }
        command, arg_str = $4, $5
      elsif comm =~ /^:(#{@nick_regex})\s+([A-Z]+)\s+(.*?)[\r\n]*$/ then
        sender = { :nick => $1 }
        command, arg_str = $2, $3
      elsif comm =~ /^:([^\s:]+?)\s+([A-Z]+)\s+(.*?)[\r\n]*$/ then
        server, command, arg_str = $1, $2, $3
        arg_array, msg = split_out_message(arg_str)
      elsif comm =~ /^(\w+)\s+:(.+?)[\r\n]*$/ then
        command, msg = $1, $2
      elsif comm =~ /^:([^\s:]+?)\s+(\d+)\s+(.*?)[\r\n]*$/ then
        server, code, arg_str = $1, $2, $3
        arg_array, msg = split_out_message(arg_str)
        
        numeric_method = "irc_#{code}_response".to_sym
        readable_method = "irc_#{server_type.event[code.to_i]}_response".to_sym if not code.to_i.zero? and server_type.event?(code.to_i)
        name = arg_array.shift
        meths[numeric_method] = [ self, server, name, arg_array, msg ]
        meths[readable_method] = [ self, server, name, arg_array, msg ] if readable_method
        meths[:irc_response] = [ self, code, server, name, arg_array, msg ]
        return meths
      else
        logger.error "Couldn't parse IRC message: #{comm.inspect}"
        return meths
      end
      
      if arg_str then
        arg_array, msg = split_out_message(arg_str)
      else
        arg_array = Array.new
      end
      command = command.downcase.to_sym
    
      case command
        when :nick then
          arguments = { :nick => arg_array.at(0) }
          # Some IRC servers put the nick in the message field
          unless arguments[:nick]
            arguments[:nick] = msg
            msg = nil
          end
        when :quit then
          arguments = { }
        when :join then
          arguments = { :channel => (msg || arg_array.at(0)) }
          msg = nil
        when :part then
          arguments = { :channel => arg_array.at(0) }
        when :mode then
          arguments = if channel?(arg_array.at(0)) then { :channel => arg_array.at(0) } else { :recipient => arg_array.at(0) } end
          params = arg_array[2, arg_array.size]
          if params then
            params = params.only if params.size == 1
            params = nil if params.empty? # empty? is a method on String too, so this has to come second to prevent an error
          end
          arguments.update(:mode => arg_array.at(1), :parameter => params)
          # Usermodes stick the mode in the message
          if arguments[:mode].nil? and msg =~ /^[\+\-]\w+$/ then
            arguments[:mode] = msg
            msg = nil
          end
        when :topic then
          arguments = { :channel => arg_array.at(0), :topic => msg }
          msg = nil
        when :invite then
          arguments = { :recipient => arg_array.at(0), :channel => msg }
          msg = nil
        when :kick then
          arguments = { :channel => arg_array.at(0), :recipient => arg_array.at(1) }
        when :privmsg then
          arguments = if channel?(arg_array.at(0)) then { :channel => arg_array.at(0) } else { :recipient => arg_array.at(0) } end
        when :notice then
          arguments = if channel?(arg_array.at(0)) then { :channel => arg_array.at(0) } else { :recipient => arg_array.at(0) } end
        when :ping then
          arguments = { :server => arg_array.at(0) }
        else
          logger.warn "Unknown IRC command #{command.to_s}"
          return
      end
      arguments.update :message => msg
      arguments[:channel] = normalized_channel_name(arguments[:channel]) if arguments[:channel]
    
      method = "irc_#{command}_event".to_sym
      meths[method] = [ self, sender, arguments ]
      meths[:irc_event] = [ self, command, sender, arguments ]
      return meths
    end
    
    def split_out_message(arg_str)
      if arg_str.match(/^(.*?):(.*)$/) then
        arg_array = $1.strip.words
        msg = $2
        return arg_array, msg
      else
        # no colon in message
        return arg_str.strip.words, nil
      end
    end
    
    def post_startup
      @ready_thread = Thread.new do
        sleep 10
        should_broadcast = false
        @join_mutex.synchronize do
          should_broadcast = true unless @ready
          @ready = true
          # If irc_join_event set @ready to true, then we know that they have
          # already broadcasted, because those two events are in a critical
          # section. Otherwise, we set ready to true, thus ensuring they won't
          # broadcast, and then broadcast if they haven't already.
          @channels_to_join = nil
        end
        broadcast :stem_ready, self if should_broadcast
      end
      @channels_to_join = @channels
      @channels = Set.new
      @channels_to_join.each { |chan| join chan, @channel_passwords[chan] }
      privmsg 'NickServ', "IDENTIFY #{options[:password]}" if options[:password]
    end
    
    def update_names_list(channel, names)
      @chan_mutex.synchronize do
        @updating_channel_members[channel] ||= Hash.new
        names.each do |name|
          @updating_channel_members[channel][server_type.just_nick(name)] = server_type.nick_privilege(name)
        end
      end
    end
    
    def finish_names_list_update(channel)
      @chan_mutex.synchronize do
        @channel_members[channel] = @updating_channel_members.delete(channel) if @updating_channel_members[channel]
      end
    end
    
    def drop_channel(channel)
      @channels.delete channel
      @channel_passwords.delete channel
      @channel_members.delete channel
    end
    
    def privmsgt(*args) # a throttled privmsg
      @messages_queue << args
    end
  end
end
