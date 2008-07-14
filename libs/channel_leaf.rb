# Defines the Autumn::ChannelLeaf class, a subclass of Autumn::Leaf that
# selectively ignores channels.

module Autumn
  
  # A special kind of leaf that only responds to messages sent to certain
  # channels. Leaves that subclass ChannelLeaf can, in their config, specify a
  # +channels+ option that narrows down which channels the leaf listens to. The
  # leaf will not invoke the hook methods nor the <tt>*_command</tt> methods for
  # IRC events that are not associated with those channels. It will respond to
  # global, non-channel-specific events as well.
  #
  # You can combine multiple ChannelLeaf subclasses in one Stem to allow you to
  # run two leaves off of one nick, but have the nick running different leaves
  # in different channels.
  #
  # The +channels+ option should be a list of stems, and for each stem, a valid
  # channel. For example, if you ran your leaf on two servers, your stems.yml
  # file might look like:
  #
  #  GamingServer:
  #    channels: fishinggames, games, drivinggames
  #    [...]
  #  FishingServer:
  #    channels: fishinggames, flyfishing
  #    [...]
  #
  # Now let's say you had a trivia leaf that asked questions about fishing
  # games. You'd want to run that leaf on the "#fishinggames" channel of each
  # server, and the "#games" channel of the GamingServer, but not the other
  # channels. (Perhaps your Stem was also running other leaves relevant to those
  # channels.) You'd set up your leaves.yml file like so:
  #
  #  FishingGamesTrivia:
  #    channels:
  #      GamingServer:
  #        - fishinggames
  #        - games
  #      FishingServer: fishinggames
  #    [...]
  #
  # Now your leaf will only respond to messages relevant to the specified server
  # channels (as well as global messages).
  #
  # Interception and filtering of messages is done at the _leaf_ level, not the
  # _stem_ level. Therefore, for instance, if you override
  # +someone_did_join_channel+, it will only be called for the appropriate
  # channels; however, if you implement +irc_join_event+, it will still be
  # called for all channels the stem is in.
  
  class ChannelLeaf < Leaf
    # The IRC channels that this leaf is responding to, mapped to server names.
    attr :channels
    
    # Creates a new instance. (See the Leaf class for more information.)
    
    def will_start_up
      @channels = Hash.new
      @options[:channels] ||= Hash.new
      @options[:channels].each do |server, chans|
        stem = Foliater.instance.stems[server]
        raise "Unknown stem #{server}" unless stem
        chans = [ chans ] if chans.kind_of? String
        @channels[stem] = chans.map { |chan| stem.normalized_channel_name chan }
      end
      super
    end
    
    def irc_privmsg_event(stem, sender, arguments) # :nodoc:
      super if arguments[:channel].nil? or listening?(stem, arguments[:channel])
    end
    
    def irc_join_event(stem, sender, arguments) # :nodoc:
      super if listening?(stem, arguments[:channel])
    end

    def irc_part_event(stem, sender, arguments) # :nodoc:
      super if listening?(stem, arguments[:channel])
    end

    def irc_mode_event(stem, sender, arguments) # :nodoc:
      super if arguments[:channel].nil? or listening?(stem, arguments[:channel])
    end

    def irc_topic_event(stem, sender, arguments) # :nodoc:
      super if listening?(stem, arguments[:channel])
    end

    def irc_invite_event(stem, sender, arguments) # :nodoc:
      super if listening?(stem, arguments[:channel]) or not stem.channels.include? arguments[:channel]
    end

    def irc_kick_event(stem, sender, arguments) # :nodoc:
      super if listening?(stem, arguments[:channel])
    end

    def irc_notice_event(stem, sender, arguments) # :nodoc:
      super if arguments[:channel].nil? or listening?(stem, arguments[:channel])
    end
    
    private
    
    def listening?(stem, channel)
      @channels.include? stem and @channels[stem].include? channel
    end
  end
end
