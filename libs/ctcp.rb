# Defines the Autum::CTCP class, which implements CTCP support.

require 'time'

module Autumn

  # A listener for a Stem that listens for and handles CTCP requests. You can
  # add CTCP support for your IRC client by instantiating this object and
  # passing it to the Stem#add_listener method.
  #
  # CTCP stands for Client-to-Client Protocol and is a way that IRC clients and
  # servers can request and transmit more information about each other. Modern
  # IRC clients all have CTCP support, and many servers expect or assume that
  # their clients support CTCP. CTCP is also used as a basis for further
  # extensions to IRC, such as DCC and XDCC.
  #
  # This class implements the spec defined at http://www.invlogic.com/irc/ctcp.html
  #
  # Because some IRC servers will disconnect clients that send a large number of
  # messages in a short period of time, this listener will only send one CTCP
  # reply per second, with up to a maximum of 10 replies waiting in the queue
  # (after which new requests are ignored). These values can be adjusted in the
  # initialization options.
  #
  # This class acts as a listener plugin: Any of the methods specified below can
  # be implemented by any other listener, and will be invoked by this listener
  # when appropriate.
  #
  # To respond to incoming CTCP requests, you should implement methods of the
  # form <tt>ctcp_*_request</tt>, where "*" is replaced with the lowercase name
  # of the CTCP command. (For example, to handle VERSION requests, implement
  # +ctcp_version_request+). This method will be invoked whenever a request is
  # received by the IRC client. It will be given the following parameters:
  #
  # 1. the CTCP instance that parsed the request,
  # 2. the Stem instance that received the request,
  # 3. the person who sent the request (a hash in the form of that used by Stem;
  #    see Stem#add_listener for more information), and
  # 4. an array of arguments passed along with the request.
  #
  # In addition, you can implement +ctcp_request_received+, which will then be
  # invoked for any and all incoming CTCP requests. It is passed the following
  # arguments:
  #
  # 1. the name of the request, as a lowercase symbol,
  # 2. the CTCP instance that parsed the request,
  # 3. the Stem instance that received the request,
  # 4. the person who sent the request (a sender hash -- see the Leaf docs), and
  # 5. an array of arguments passed along with the request.
  #
  # This class will by default respond to some incoming CTCP requests and
  # generate appropriate replies; however, it does not implement any specific
  # behavior for parsing incoming replies. If you wish to parse replies, you
  # should implement methods in your listener of the form
  # <tt>ctcp_*_response</tt>, with the "*" character replaced as above. This
  # method will be invoked whenever a reply is received by this listener. You
  # can also implement <tt>ctcp_response_received</tt> just as above. The
  # parameters for these methods are the same as those listed above.
  #
  # Responses are assumed to be any CTCP messages that are sent as a NOTICE (as
  # opposed to a PRIVMSG). Because they are NOTICEs, your program should not
  # send a message in response.
  #
  # In addition to responding to incoming CTCP requests and replies, your
  # listener can use its stem to send CTCP requests and replies. See the added
  # method for more detail.

  class CTCP
    # Format of an embedded CTCP request.
    CTCP_REQUEST = /\x01(.+?)\x01/
    # CTCP commands whose arguments are encoded according to the CTCP spec (as
    # opposed to other commands, whose arguments are plaintext).
    ENCODED_COMMANDS = [ 'VERSION', 'PING' ]
    
    # Creates a new CTCP parser. Options are:
    #
    # +reply_queue_size+:: The maximum number of pending replies to store in the
    #                      queue, after which new CTCP requests are ignored.
    # +reply_rate+:: The minimum time, in seconds, between consecutive CTCP
    #                replies.
    
    def initialize(options={})
      @options = options
      @options[:reply_queue_size] ||= 10
      @options[:reply_rate] ||= 0.25
      @reply_thread = Hash.new
      @reply_queue = Hash.new do |hsh, key|
        hsh[key] = ForgetfulQueue.new(@options[:reply_queue_size])
        @reply_thread[key] = Thread.new(key) do |stem|
          loop do #TODO wake thread when stem is quitting so this thread can terminate?
            reply = @reply_queue[stem].pop
            stem.notice reply[:recipient], reply[:message]
            sleep @options[:reply_rate]
          end
        end
        hsh[key]
      end
    end
    
    # Parses CTCP requests in a PRIVMSG event.
    
    def irc_privmsg_event(stem, sender, arguments) # :nodoc:
      arguments[:message].scan(CTCP_REQUEST).flatten.each do |ctcp|
        ctcp_args = ctcp.split(' ')
        request = ctcp_args.shift
        ctcp_args = ctcp_args.map { |arg| unquote arg } if ENCODED_COMMANDS.include? request
        meth = "ctcp_#{request.downcase}_request".to_sym
        stem.broadcast meth, self, stem, sender, ctcp_args
        stem.broadcast :ctcp_request_received, request.downcase.to_sym, self, stem, sender, ctcp_args
      end
    end
    
    # Parses CTCP responses in a NOTICE event.
    
    def irc_notice_event(stem, sender, arguments) # :nodoc:
      arguments[:message].scan(CTCP_REQUEST).flatten.each do |ctcp|
        ctcp_args = ctcp.split(' ')
        request = ctcp_args.shift
        ctcp_args = ctcp_args.map { |arg| unquote arg } if ENCODED_COMMANDS.include? request
        meth = "ctcp_#{request.downcase}_response".to_sym
        stem.broadcast meth, self, stem, sender, ctcp_args
        stem.broadcast :ctcp_response_received, request.downcase.to_sym, self, stem, sender, ctcp_args
      end
    end
    
    # Replies to a CTCP VERSION request by sending:
    #
    # * the name of the IRC client ("Autumn, a Ruby IRC framework"),
    # * the operating system name and version, and
    # * the home page URL for Autumn.
    #
    # To determine the OS name and version, this method runs the <tt>uname
    # -sr</tt> command; if your operating system does not support this command,
    # you should override this method.
    #
    # Although the CTCP spec states that the VERSION response should be three
    # encoded strings (as shown above), many modern clients expect one plaintext
    # string. If you'd prefer compatibility with those clients, you should
    # override this method to return a single plaintext string and remove the
    # VERSION command from +ENCODED_COMMANDS+.
    
    def ctcp_version_request(handler, stem, sender, arguments)
      return unless handler == self
      send_ctcp_reply stem, sender[:nick], 'VERSION', "Autumn #{AUTUMN_VERSION}, a Ruby IRC framework", `uname -sr`.chomp, "http://github.com/RISCfuture/autumn"
    end
    
    # Replies to a CTCP PING request by sending back the same arguments as a
    # PONG reply.
    
    def ctcp_ping_request(handler, stem, sender, arguments)
      return unless handler == self
      send_ctcp_reply stem, sender[:nick], 'PING', *arguments
    end
    
    # Replies to a CTCP TIME request by sending back the local time in RFC-822
    # format.
    
    def ctcp_time_request(handler, stem, sender, arguments)
      return unless handler == self
      send_ctcp_reply stem, sender[:nick], 'TIME', Time.now.rfc822
    end
    
    # Adds a CTCP reply to the queue. You must pass the Stem instance that will
    # be sending this reply, the recipient (channel or nick), and the name of
    # the CTCP command (as an uppercase string). Any additional arguments are
    # taken to be arguments of the CTCP reply, and are thus encoded and joined
    # by space characters, as specified in the CTCP white paper. The arguments
    # should all be strings.
    #
    # +recipient+ can be a nick, a channel name, or a sender hash, as necessary.
    # Encoding of arguments is only done for commands in +ENCODED_COMMANDS+.
    
    def send_ctcp_reply(stem, recipient, command, *arguments)
      recipient = recipient[:nick] if recipient.kind_of? Hash
      @reply_queue[stem] << { :recipient => recipient, :message => make_ctcp_message(command, *arguments) }
    end
    
    # When this listener is added to a stem, the stem gains the ability to send
    # CTCP messages directly. Methods of the form <tt>ctcp_*</tt>, where "*" is
    # the lowercase name of a CTCP action, will be forwarded to this listener,
    # which will send the CTCP message. The first parameter of the method is the
    # nick of one or more recipients; all other parameters are parameters for
    # the CTCP command. See the CTCP spec for more information on the different
    # commands and parameters available.
    #
    # For example, to send an action (such as "/me is cold") to a channel:
    #
    #  stem.ctcp_action "#channel", "is cold"
    #
    # In addition, the stem gains the ability to send CTCP replies. Replies are
    # messages that are added to this class's reply queue, adding flood abuse
    # prevention. To send a reply, call a Stem method of the form
    # <tt>ctcp_reply_*</tt>, where "*" is the command name you are replying to,
    # in lowercase. Pass first the nick or sender hash of the recipient, then
    # any parameters as specified by the CTCP spec. For example, to respond to a
    # CTCP VERSION request:
    #
    #  stem.ctcp_reply_version sender, 'Bot Name', 'Computer Name', 'Other Info'
    #
    # (Note that responding to VERSION requests is already handled by this class
    # so you'll need to either override or delete the ctcp_version_request
    # method to do this.)
    
    def added(stem)
      stem.instance_variable_set :@ctcp, self
      class << stem
        def method_missing(meth, *args)
          if meth.to_s =~ /^ctcp_reply_([a-z]+)$/ then
            @ctcp.send_ctcp_reply self, args.shift, $1.to_s.upcase, *args
          elsif meth.to_s =~ /^ctcp_([a-z]+)$/ then
            privmsg args.shift, @ctcp.make_ctcp_message($1.to_s.upcase, *args)
          else
            super
          end
        end
      end
    end
    
    # Creates a CTCP-formatted message with the given command (uppercase string)
    # and arguments (strings). The string returned is suitable for transmission
    # over IRC using the PRIVMSG command.
    
    def make_ctcp_message(command, *arguments)
      arguments = arguments.map { |arg| quote arg } if ENCODED_COMMANDS.include? command
      "\01#{arguments.unshift(command).join(' ')}\01"
    end
    
    private
    
    def quote(str)
      chars = str.split('')
      chars.map! do |char|
        case char
          when "\0" then '\0'
          when "\1" then '\1'
          when "\n" then '\n'
          when "\r" then '\r'
          when " " then '\@'
          when "\\" then '\\\\'
          else char
        end
      end
      return chars.join
    end
    
    def unquote(str)
      str.gsub('\\\\', '\\').gsub('\@', " ").gsub('\r', "\r").gsub('\n', "\n").gsub('\1', "\1").gsub('\0', "\0")
    end
  end
end
