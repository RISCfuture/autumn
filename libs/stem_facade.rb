# Defines the Autumn::StemFacade class, which provides additional convenience
# methods to Autumn::Stem.

module Autumn
  
  # A collection of convenience methods that are added to the Stem class. These
  # methods serve two purposes; one, to allow easier backwards compatibility
  # with Autumn Leaves 1.0 (which had a simpler one-stem-per-leaf approach), and
  # two, to make it easier or more Ruby-like to perform certain IRC actions.
  
  module StemFacade
    
    # Sends a message to one or more channels or nicks. If no channels or nicks
    # are specified, broadcasts the message to every channel the stem is in. If
    # you are sending a message to a channel you must prefix it correctly; the
    # "#" will not be added before the channel name for you.
    #
    #  message "Look at me!" # Broadcasts to all channels
    #  message "I love kitties", '#kitties' # Sends a message to one channel or person
    #  message "Learn to RTFM", '#help', 'NoobGuy' # Sends a message to two channels or people
    
    def message(msg, *chans)
      return if msg.nil? or msg.empty?
      chans = channels if chans.empty?
      if @throttle then
        Thread.exclusive { msg.each_line { |line| privmsgt chans.to_a, line.strip unless line.strip.empty? } }
      else
        msg.each_line { |line| privmsg chans.to_a, line.strip unless line.strip.empty? }
      end
    end
    
    # Sets the topic for one or more channels. If no channels are specified,
    # sets the topic of every channel the stem is in.
    #
    #  set_topic "Bots sure are fun!", 'bots', 'morebots'
    
    def set_topic(motd, *chans)
      return if motd.nil?
      chans = chans.empty? ? channels : chans.map { |chan| normalized_channel_name chan }
      chans.each { |chan| topic chan, motd }
    end
    
    # Joins a channel by name. If the channel is password-protected, specify the
    # +password+ parameter. Of course, you could always just call the +join+
    # method (since each IRC command has a method named after it), but the
    # advantage to using this method is that it will also update the
    # <tt>@channel_passwords</tt> instance variable. Internal consistency is a
    # good thing, so please use this method.
    
    def join_channel(channel, password=nil)
      channel = normalized_channel_name(channel)
      return if channels.include? channel
      join channel, password
      @channel_passwords[channel] = password if password
    end

    # Leaves a channel, specified by name.
    
    def leave_channel(channel)
      channel = normalized_channel_name(channel)
      return unless channels.include? channel
      part channel
    end

    # Changes this stem's IRC nick. Note that the stem's original nick will
    # still be used by the logger.
    
    def change_nick(new_nick)
      nick new_nick
    end

    # Grants a privilege to a channel member, such as voicing a member. The stem
    # must have the required privilege level to perform this command.
    # +privilege+ can either be a symbol from the Daemon instance or a string
    # with the letter code for the privilege.
    #
    #  grant_user_privilege 'mychannel', 'Somedude', :operator
    #  grant_user_privilege '#mychannel', 'Somedude', 'oa'
    
    def grant_user_privilege(channel, nick, privilege)
      channel = normalized_channel_name(channel)
      privcode = server_type.privilege.key(privilege).chr if server_type.privilege.value? privilege
      privcode ||= privilege
      mode channel, "+#{privcode}", nick
    end

    # Removes a privilege to a channel member, such as voicing a member. The
    # stem must have the required privilege level to perform this command.
    # +privilege+ can either be a symbol from the Daemon instance or a string
    # with the letter code for the privilege.
    
    def remove_user_privilege(channel, nick, privilege)
      channel = normalized_channel_name(channel)
      privcode = server_type.privilege.key(privilege).chr if server_type.privilege.value? privilege
      privcode ||= privilege
      mode channel, "-#{privcode}", nick
    end
    
    # Grants a usermode to an IRC nick, such as making a nick invisible.
    # The stem must have the required privilege level to perform this command.
    # (Generally, one can only change his own usermode unless he is a server
    # op.) +mode+ can either be a symbol from the Daemon instance or a string
    # with the letter code for the usermode.
    #
    #  grant_usermode 'Spycloak', :invisible
    #  grant_usermode 'UpMobility', 'os'
    
    def grant_usermode(nick, property)
      propcode = server_type.usermode.key(property).chr if server_type.usermode.value? property
      propcode ||= property
      mode nick, "+#{property}"
    end

    # Revokes a usermode from an IRC nick, such as removing invisibility. The
    # stem must have the required privilege level to perform this command.
    # (Generally, one can only change his own usermode unless he is a server
    # op.) +mode+ can either be a symbol from the Daemon instance or a string
    # with the letter code for the usermode.
    
    def remove_usermode(nick, property)
      propcode = server_type.usermode.key(property).chr if server_type.usermode.value? property
      propcode ||= property
      mode nick, "-#{property}"
    end

    # Sets a property of a channel, such as moderated. The stem must have the
    # required privilege level to perform this command. +property+ can either be
    # a symbol from the Daemon instance or a string with the letter code for the
    # property. If the property takes an argument (such as when setting a
    # channel password), pass it as the +argument+ paramter.
    #
    #  set_channel_property '#mychannel', :secret
    #  set_channel_property 'mychannel', :keylock, 'mypassword'
    #  set_channel_property '#mychannel', 'ntr'
    
    def set_channel_property(channel, property, argument=nil)
      channel = normalized_channel_name(channel)
      propcode = server_type.channel_property.key(property).chr if server_type.channel_property.value? property
      propcode ||= property
      mode channel, "+#{propcode}", argument
    end

    # Removes a property of a channel, such as moderated. The stem must have the
    # required privilege level to perform this command. +property+ can either be
    # a symbol from the Daemon instance or a string with the letter code for the
    # property. If the property takes an argument (such as when removing a
    # channel password), pass it as the +argument+ paramter.
    
    def unset_channel_property(channel, property, argument=nil)
      channel = normalized_channel_name(channel)
      propcode = server_type.channel_property.key(property).chr if server_type.channel_property.value? property
      propcode ||= property
      mode channel, "-#{propcode}", argument
    end
    
    # Returns an array of nicks for users that are in a channel.
    
    def users(channel)
      channel = normalized_channel_name(channel)
      @chan_mutex.synchronize { @channel_members[channel] && @channel_members[channel].keys }
    end
  
    # Returns the privilege level of a channel member. The privilege level will
    # be a symbol from the Daemon instance. Returns nil if the channel member
    # doesn't exist or if the bot is not on the given channel. Returns an array
    # of privileges if the server supports multiple privileges per user, and the
    # user has more than one privilege.
    #
    # +user+ can be a nick or a sender hash.
    
    def privilege(channel, user)
      user = user[:nick] if user.kind_of? Hash
      @chan_mutex.synchronize { @channel_members[channel] && @channel_members[channel][user] }
    end
  end
end
