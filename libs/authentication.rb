# Defines the Autumn::Authentication class, which includes different
# authentication strategies available to leaves.

module Autumn
  
  # Defines classes which each encapsulate a different strategy for
  # authentication. When the +authentication+ option is specified (see the
  # Autumn::Leaf class), the options given are used to choose the correct class
  # within this module to serve as the authenticator for that leaf.
  #
  # These authentication strategies are used to ensure only authorized users
  # have access to protected commands. Leaf authors can designate certain
  # commands as protected.
  #
  # = Writing Your Own Authenticators
  #
  # When the Autumn::Leaf#authenticate method is called, it converts the symbol
  # from snake_case to CamelCase, and looks for a class in this model. Thus, a
  # call to <tt>authenticate :hostname</tt> would look for a class
  # Autumn::Authentication::Hostname.
  #
  # To define your own authenticator, subclass Autumn::Authentication::Base as a
  # new class in the Autumn::Authentication module. Implement the methods
  # defined in the Autumn::Authentication::Base class docs, then adjust your
  # configuration to use your new authenticator.
  
  module Authentication
    
    # The basic subclass for all authenticators. If you wish to write your own
    # authenticator, you must subclass this class. You must at a minimum
    # override the authenticate method. You should also override the initialize
    # method if you need to store any options or other data for later use.
    #
    # The authentication module will become a stem listener, so see
    # Autumn::Stem#add_listener for information on other methods you can
    # implement.
    
    class Base
      
      # Stores the options for this authenticator and configures it for use.
      
      def initialize(options={})
        raise "You can only instantiate subclasses of this class."
      end
      
      # Returns true if the user is authorized, false if not. +sender+ is a
      # sender hash as defined in the Autumn::Stem docs.
      
      def authenticate(stem, channel, sender, leaf)
        raise "Subclasses must override the Autumn::Authentication::Base#authenticate method."
      end
      
      # Returns a string to be displayed to a user who is not authorized to
      # perform a command. Override this method to provide more specific hints
      # to a user on what he can do to authorize himself (e.g., "Tell me your
      # password").
      
      def unauthorized
        "You must be an administrator for this bot to do that."
      end
    end
    
    # Authenticates users by their privilege level in the channel they ran the
    # command in.
    # 
    # This is a quick, configuration-free way of protecting your leaf, so long
    # as you trust the ops in your channel.
    
    class Op < Base
      
      # Creates a new authenticator. Pass a list of allowed privileges (as
      # symbols) for the +privileges+ option. By default this class accepts ops,
      # admins, and channel owners/founders as authorized.
      
      def initialize(options={})
        @privileges = options[:privileges]
        @privileges ||= [ :operator, :oper, :op, :admin, :founder, :channel_owner ]
      end
            
      def authenticate(stem, channel, sender, leaf) # :nodoc:
        # Returns true if the sender has any of the privileges listed below
        not (@privileges & [ stem.privilege(channel, sender) ].flatten).empty?
      end
      
      def unauthorized # :nodoc:
        "You must be an op to do that."
      end
    end
    
    # Authenticates by IRC nick. A list of allowed nicks is built on
    # initialization, and anyone with that nick is allowed to use restricted
    # commands.
    # 
    # This is the most obvious approach to authentication, but it is hardly
    # secure. Anyone can change their nick to an admin's nick once that admin
    # logs out.
    
    class Nick < Base
      
      # Creates a new authenticator. Pass a single nick for the +nick+ option or
      # an array of allowed nicks for the +nicks+ option. If neither option is
      # set, an exception is raised.
      
      def initialize(options={})
        @nicks = options[:nick]
        @nicks ||= options[:nicks]
        raise "You must give the nick of an administrator to use nick-based authentication." if @nicks.nil?
        @nicks = [ @nicks ] if @nicks.kind_of? String
      end
            
      def authenticate(stem, channel, sender, leaf) # :nodoc:
        @nicks.include? sender[:nick]
      end
    end
    
    # Authenticates by the host portion of an IRC message. A hostmask is used to
    # match the relevant portion of the address with a whitelist of accepted
    # host addresses.
    # 
    # This method can be a secure way of preventing unauthorized access if you
    # choose an appropriately narrow hostmask. However, you must configure in
    # advance the computers you may want to administrate your leaves from.
    
    class Hostname < Base
      
      # Creates a new authenticator. You provide a hostmask via the +hostmask+
      # option -- either a Regexp with one capture (that captures the portion of
      # the hostmask you are interested in), or a Proc, which takes a host as an
      # argument and returns true if the host is authorized, false if not. If
      # the +hostmask+ option is not provided, a standard hostmask regexp will
      # be used. This regexp strips everything left of the first period; for the
      # example hostmask "wsd1.ca.widgetcom.net", it would return
      # "ca.widgetcom.net" to be used for comparison.
      # 
      # You also provide an authorized host with the +host+ option, or a list of
      # such hosts with the +hosts+ option. If neither is given, an exception is
      # raised.
      
      def initialize(options={})
        @hostmask = options[:hostmask]
        @hostmask ||= /^.+?\.(.+)$/
        @hostmask = @hostmask.to_rx(false) if @hostmask.kind_of? String
        if @hostmask.kind_of? Regexp then
          mask = @hostmask
          @hostmask = lambda do |host|
            if matches = host.match(mask) then matches[1] else nil end
          end
        end
                
        @hosts = options[:host]
        @hosts ||= options[:hosts]
        raise "You must give the host address of an administrator to use nick-based authentication." unless @hosts
        @hosts = [ @hosts ] unless @hosts.kind_of? Array
      end
      
      def authenticate(stem, channel, sender, leaf) # :nodoc:
        @hosts.include? @hostmask.call(sender[:host])
      end
    end
    
    # Authenticates by a password provided in secret. When a user PRIVMSG's the
    # leaf the correct password, the leaf adds that user's nick to a list of
    # authorized nicks. These credentials expire when the person changes his
    # nick, logs out, leaves the channel, etc. They also expire if a certain
    # amount of time passes without running any protected commands.
    
    class Password < Base
      # The default period of time that must occur with no use of protected
      # commands after which a user's credentials expire.
      DEFAULT_EXPIRE_TIME = 5*60
      
      # Creates a new authenticator. You provide a valid password with the
      # +password+ option. If that option is not provided, an exception is
      # raised. You can pass a number of seconds to the +expire_time+ option;
      # this is the amount of time that must pass with no protected commands for
      # a nick's authorization to expire. If the +expire_time+ option is not
      # given, a default value of five minutes is used.
      
      def initialize(options={})
        @password = options[:password]
        @expire_time = options[:expire_time]
        @expire_time ||= DEFAULT_EXPIRE_TIME
        raise "You must provide a password to use password-based authentication" unless @password
        @authorized_nicks = Hash.new { |hsh, key| hsh[key] = Set.new }
        @last_protected_action = Hash.new { |hsh, key| hsh[key] = Hash.new(Time.at(0)) }
        @an_lock = Mutex.new
      end
      
      def irc_privmsg_event(stem, sender, arguments) # :nodoc:
        if arguments[:recipient] and arguments[:message] == @password then
          @an_lock.synchronize do
            @authorized_nicks[stem] << sender[:nick]
            @last_protected_action[stem][sender[:nick]] = Time.now
            #TODO values are not always deleted; this hash has the possibility to slowly grow and consume more memory
          end
          stem.message "Your password has been accepted, and you are now authorized.", sender[:nick]
        end
      end
      
      def irc_nick_event(stem, sender, arguments) # :nodoc:
        @an_lock.synchronize do
          revoke stem, sender[:nick]
          revoke stem, arguments[:nick]
        end
      end
      
      def irc_kick_event(stem, sender, arguments) # :nodoc:
        @an_lock.synchronize { revoke stem, arguments[:nick] }
      end
      
      def irc_quit_event(stem, sender, arguments) # :nodoc:
        @an_lock.synchronize { revoke stem, sender[:nick] }
      end
      
      def authenticate(stem, channel, sender, leaf) # :nodoc:
        @an_lock.synchronize do
          if Time.now - @last_protected_action[stem][sender[:nick]] > @expire_time then
            revoke stem, sender[:nick]
          else
            @last_protected_action[stem][sender[:nick]] = Time.now
          end
          @authorized_nicks[stem].include? sender[:nick]
        end
      end
      
      def unauthorized # :nodoc:
        "You must authenticate with an administrator password to do that."
      end
      
      private
      
      def revoke(stem, nick)
        @authorized_nicks[stem].delete nick
        @last_protected_action[stem].delete nick
      end
    end
  end
end
