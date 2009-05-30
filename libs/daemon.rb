# Defines the Autumn::Daemon class, which stores information on the different
# implementations of IRC by different server daemons.

module Autumn
  
  # Describes an IRC server daemon program. Different IRC servers run off of
  # different IRC daemons, each of which has a slightly different implementation
  # of the IRC protocol. To encapsulate this, the Daemon class stores the names
  # of some of the more common IRC server types, as well as the unique
  # information about those daemons, such as supported usermodes, response
  # codes, and supported channel types.
  #
  # An instance of Daemon is an IRC server type. The Daemon class keeps a
  # catalog of all instances, assigning each a descriptive name (for example,
  # "Unreal" for the UnrealIRCd program, a popular IRC server daemon).
  #
  # A Daemon instance can be queried for information about the IRC server type,
  # as necessary to parse messages from that IRC server.
  #
  # A "default" daemon will also be created representing a common denominator of
  # IRC features, which is used in situations where a server's exact type is
  # unknown. This daemon will consist of all non-conflicting entries among the
  # defined daemons.
  #
  # In addition to the methods and attributes below, you can also call predicate
  # methods such as <tt>usermode?</tt> and <tt>channel_prefix?</tt> to test if a
  # character is in a set of known modes/privileges/prefixes, or if a number is
  # in the set of known events.
  
  class Daemon
        
    # Creates a new Daemon instance associated with a given name. You must also
    # pass in the hashes for it to store.
    
    def initialize(name, info)
      if name.nil? and info.nil? then # it's the default hash
        raise "Already created a default Daemon" if self.class.class_variable_defined? :@@default
        @usermode = Hash.parroting
        @privilege = Hash.parroting
        @user_prefix = Hash.parroting
        @channel_prefix = Hash.parroting
        @channel_mode = Hash.parroting
        @server_mode = Hash.parroting
        @event = Hash.parroting
        @default = true
      else
        @usermode = Hash.parroting(info['usermode'])
        @privilege = Hash.parroting(info['privilege'])
        @user_prefix = Hash.parroting(info['user_prefix'])
        @channel_prefix = Hash.parroting(info['channel_prefix'])
        @channel_mode = Hash.parroting(info['channel_mode'])
        @server_mode = Hash.parroting(info['server_mode'])
        @event = Hash.parroting(info['event'])
        @@instances[name] = self

        # Build up our default so it contains all keys with no conflicting
        # values across different server specs. Delete keys from the default
        # hash for which we found duplicates.
        info.each do |hname, hsh|
          next unless @@default.respond_to? hname.to_sym
          default_hash = @@default.send(hname.to_sym)
          
          uniques = hsh.reject { |k, v| default_hash.include? k }
          default_hash.update uniques
          default_hash.reject! { |k, v| hsh.include?(k) and hsh[k] != v }
        end
      end
    end
    
    # Returns a Daemon instance by associated name.
    
    def self.[](name)
      @@instances[name]
    end
    
    # Returns the fallback server type.
    
    def self.default
      @@default
    end
    
    # Yields the name of each Daemon registered with the class.
    
    def self.each_name
      @@instances.keys.sort.each { |name| yield name }
    end
    
    # Hash of usermode characters (e.g., <tt>i</tt>) to their symbol
    # representations (e.g., <tt>:invisible</tt>).
    
    def usermode
      @default ? @usermode : @@default.usermode.merge(@usermode)
    end
    
    # Hash of user privilege characters (e.g., <tt>v</tt>) to their symbol
    # representations (e.g., <tt>:voiced</tt>).
    
    def privilege
      @default ? @privilege : @@default.privilege.merge(@privilege)
    end
    
    # Hash of user privilege prefixes (e.g., <tt>@</tt>) to their symbol
    # representations (e.g., <tt>:operator</tt>).
    
    def user_prefix
      @default ? @user_prefix : @@default.user_prefix.merge(@user_prefix)
    end
    
    # Hash of channel prefixes (e.g., <tt>&</tt>) to their symbol
    # representations (e.g., <tt>:local</tt>).
    
    def channel_prefix
      @default ? @channel_prefix : @@default.channel_prefix.merge(@channel_prefix)
    end
    
    # Hash of channel mode characters (e.g., <tt>m</tt>) to their symbol
    # representations (e.g., <tt>:moderated</tt>).
    
    def channel_mode
      @default ? @channel_mode : @@default.channel_mode.merge(@channel_mode)
    end
    
    # Hash of server mode characters (e.g., <tt>H</tt>) to their symbol
    # representations (e.g., <tt>:hidden</tt>).
    
    def server_mode
      @default ? @server_mode : @@default.server_mode.merge(@server_mode)
    end
    
    # Hash of numerical event codes (e.g., 372) to their symbol representations
    # (e.g., <tt>:motd</tt>).
    
    def event
      @default ? @event : @@default.event.merge(@event)
    end
    
    # Returns true if the mode string (e.g., "+v") appears to be changing a user
    # privilege as opposed to a channel mode.
    
    def privilege_mode?(mode)
      raise ArgumentError, "Invalid mode string '#{mode}'" unless mode =~ /^[\+\-]\S+$/
      mode.except_first.chars.all? { |c| privilege? c }
    end

    # Returns true if the first character(s) of a nick are valid privilege
    # prefixes.

    def nick_prefixed?(nick)
      user_prefix? nick[0,1]
    end

    # Given a nick, returns that nick stripped of any privilege characters on
    # the left side.

    def just_nick(name)
      nick = name.dup
      while nick_prefixed?(nick)
        nick.slice! 0, 1
      end
      return nick
    end

    # Given a nick, returns the privileges granted to this nick, as indicated by
    # the prefix characters. Returns :unvoiced if no prefix characters are
    # present. Returns an array of privileges if multiple prefix characters are
    # present.

    def nick_privilege(name)
      privs = Set.new
      nick = name.dup
      while user_prefix? nick[0,1]
        privs << user_prefix[nick[0,1]]
        nick.slice! 0, 1
      end
      case privs.size
        when 0 then :unvoiced
        when 1 then privs.only
        else privs
      end
    end
    
    def method_missing(meth, *args) # :nodoc:
      if meth.to_s =~ /^([a-z_]+)\?$/ then
        base = $1
        if (instance_variables.include?("@#{base}") or instance_variables.include?("@#{base}".to_sym)) and args.size == 1 then
          if base.end_with?('_prefix') and args.only.kind_of?(Numeric) then
            arg = args.only.chr
          else
            arg = args.only
          end
          eval "#{base}.include? #{arg.inspect}"
        end
      else
        super
      end
    end
    
    def inspect # :nodoc:
      "#<#{self.class.to_s} #{@@instances.key self}>"
    end
    
    private
    
    @@instances = Hash.new
    @@default = self.new(nil, nil)
  end
end
