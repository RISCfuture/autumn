module Autumn

  # A collection of convenience methods that are added to the Stem class. These
  # methods serve two purposes: one, to allow easier backwards compatibility
  # with Autumn Leaves 1.0 (which had a simpler one-stem-per-leaf approach), and
  # two, to make it easier or more Ruby-like to perform certain IRC actions.

  module StemFacade

    # Sends a message to one or more channels or nicks. If no channels or nicks
    # are specified, broadcasts the message to every channel the stem is in. If
    # you are sending a message to a channel you must prefix it correctly; the
    # "#" will not be added before the channel name for you.
    #
    # @example
    #   message "Look at me!" # Broadcasts to all channels
    #   message "I love kitties", '#kitties' # Sends a message to one channel or person
    #   message "Learn to RTFM", '#help', 'NoobGuy' # Sends a message to two channels or people
    #
    # @param [String] msg The message to send.
    # @param [Array<String>] chans The channels or nicks to broadcast to
    #   (channels must include prefix).

    def message(msg, *chans)
      return if msg.blank?
      chans = channels if chans.empty?
      if @throttle
        (@message_mutex ||= Mutex.new).synchronize do
          msg.each_line { |line| privmsgt chans.to_a, line.strip unless line.strip.empty? }
        end
      else
        msg.each_line { |line| privmsg chans.to_a, line.strip unless line.strip.empty? }
      end
    end

    # Sets the topic for one or more channels. If no channels are specified,
    # sets the topic of every channel the stem is in.
    #
    # @example
    #   set_topic "Bots sure are fun!", 'bots', 'morebots'
    #
    # @param [String] motd The new topic.
    # @param [Array<String>] chans The channels to set the topic for.

    def set_topic(motd, *chans)
      return if motd.nil?
      chans = chans.empty? ? channels : chans.map { |chan| normalized_channel_name chan }
      chans.each { |chan| topic chan, motd }
    end

    # Joins a channel by name. If the channel is password-protected, specify the
    # `password` parameter. Of course, you could always just call the `join`
    # method (since each IRC command has a method named after it), but the
    # advantage to using this method is that it will also update the
    # `@channel_passwords` instance variable. Internal consistency is a good
    # thing, so please use this method.
    #
    # @param [String] channel The channel to join.
    # @param [String] password The password for the channel, if it is
    #   password-protected.

    def join_channel(channel, password=nil)
      channel = normalized_channel_name(channel)
      return if channels.include? channel
      join channel, password
      @channel_passwords[channel] = password if password
    end

    # Leaves a channel, specified by name.
    #
    # @param [String] channel The channel to leave.

    def leave_channel(channel)
      channel = normalized_channel_name(channel)
      return unless channels.include? channel
      part channel
    end

    # Changes this stem's IRC nick. Note that the stem's original nick will
    # still be used by the logger.
    #
    # @param [String] new_nick The new nickname.

    def change_nick(new_nick)
      nick new_nick
    end

    # Grants a privilege to a channel member, such as voicing a member. The stem
    # must have the required privilege level to perform this command.
    #
    # @example
    #   grant_user_privilege 'mychannel', 'Somedude', :operator
    #   grant_user_privilege '#mychannel', 'Somedude', 'oa'
    #
    # @param [String] channel The channel to grant the user the privilege for.
    # @param [String] nick The user's nickname.
    # @param [Symbol, String] privilege The privilege to grant (can either be a
    #   symbol from the {Daemon} instance or a string with the letter code for
    #   the privilege.)

    def grant_user_privilege(channel, nick, privilege)
      channel = normalized_channel_name(channel)
      privcode = server_type.privilege.key(privilege).chr if server_type.privilege.value? privilege
      privcode ||= privilege
      mode channel, "+#{privcode}", nick
    end

    # Removes a privilege to a channel member, such as voicing a member. The
    # stem must have the required privilege level to perform this command.
    #
    # @param [String] channel The channel to revoke the user the privilege for.
    # @param [String] nick The user's nickname.
    # @param [Symbol, String] privilege The privilege to revoke (can either be a
    #   symbol from the {Daemon} instance or a string with the letter code for
    #   the privilege.)

    def remove_user_privilege(channel, nick, privilege)
      channel = normalized_channel_name(channel)
      privcode = server_type.privilege.key(privilege).chr if server_type.privilege.value? privilege
      privcode ||= privilege
      mode channel, "-#{privcode}", nick
    end

    # Grants a usermode to an IRC nick, such as making a nick invisible.
    # The stem must have the required privilege level to perform this command.
    # (Generally, one can only change his own usermode unless he is a server
    # op.)
    #
    # @example
    #   grant_usermode 'Spycloak', :invisible
    #   grant_usermode 'UpMobility', 'os'
    #
    # @param [String] nick The user's nickname.
    # @param [Symbol, String] property The usermode to set (can either be a
    #   symbol from the {Daemon} instance or a string with the letter code for
    #   the usermode.)

    def grant_usermode(nick, property)
      propcode = server_type.usermode.key(property).chr if server_type.usermode.value? property
      propcode ||= property
      mode nick, "+#{propcode}"
    end

    # Revokes a usermode from an IRC nick, such as removing invisibility. The
    # stem must have the required privilege level to perform this command.
    # (Generally, one can only change his own usermode unless he is a server
    # op.)
    #
    # @param [String] nick The user's nickname.
    # @param [Symbol, String] property The usermode to remove (can either be a
    #   symbol from the {Daemon} instance or a string with the letter code for
    #   the usermode.)

    def remove_usermode(nick, property)
      propcode = server_type.usermode.key(property).chr if server_type.usermode.value? property
      propcode ||= property
      mode nick, "-#{propcode}"
    end

    # Sets a property of a channel, such as moderated. The stem must have the
    # required privilege level to perform this command.
    #
    # @example
    #   set_channel_property '#mychannel', :secret
    #   set_channel_property 'mychannel', :keylock, 'mypassword'
    #   set_channel_property '#mychannel', 'ntr'
    #
    # @param [String] channel The channel name.
    # @param [Symbol, String] property The channel mode to remove (can either be
    #   a symbol from the {Daemon} instance or a string with the letter code for
    #   the mode.)
    # @param [String] argument An argument to provide with the channel mode.

    def set_channel_property(channel, property, argument=nil)
      channel = normalized_channel_name(channel)
      propcode = server_type.channel_mode.key(property).chr if server_type.channel_mode.value? property
      propcode ||= property
      mode channel, "+#{propcode}", argument
    end

    # Removes a property of a channel, such as moderated. The stem must have the
    # required privilege level to perform this command.
    #
    # @param [String] channel The channel name.
    # @param [Symbol, String] property The channel mode to remove (can either be
    #   a symbol from the {Daemon} instance or a string with the letter code for
    #   the mode.)
    # @param [String] argument An argument to provide with the channel mode.

    def unset_channel_property(channel, property, argument=nil)
      channel = normalized_channel_name(channel)
      propcode = server_type.channel_mode.key(property).chr if server_type.channel_mode.value? property
      propcode ||= property
      mode channel, "-#{propcode}", argument
    end

    # Returns an array of nicks for users that are in a channel.
    #
    # @param [String] channel The channel name.
    # @return [Array<String>] The users in the channel.

    def users(channel)
      channel = normalized_channel_name(channel)
      @chan_mutex.synchronize { @channel_members[channel] && @channel_members[channel].keys }
    end

    # Returns the privilege level of a channel member. The privilege level will
    # be a symbol from the {Daemon} instance. Returns `nil` if the channel
    # member doesn't exist or if the bot is not on the given channel. Returns an
    # array of privileges if the server supports multiple privileges per user,
    # and the user has more than one privilege.
    #
    # @param [String] channel A channel name.
    # @param [String, Hash] user The user nick or sender hash.
    # @return [Symbol, Array<Symbol>, nil] The privilege or privileges this user
    #   has.

    def privilege(channel, user)
      user = user[:nick] if user.kind_of? Hash
      @chan_mutex.synchronize { @channel_members[channel] && @channel_members[channel][user] }
    end
  end
end
