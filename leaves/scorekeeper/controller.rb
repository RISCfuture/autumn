require 'dm-ar-finders'

begin
  gem 'chronic'
  require 'chronic'
rescue Gem::LoadError
  # Install the "chronic" gem for more robust date parsing
end

# An Autumn Leaf used for an in-channel scorekeeping system. This can operate
# both as an open or closed score system. (In the former, new members are
# automatically added when they receive points; in the latter, only authorized
# members can give and receive points.)
#
# Scorekeeper is a database-backed leaf. It requires the DataMapper gem in order
# to run. The database stores channels and their members, and each member's
# point history.
#
# Scorekeeper supports pseudonyms. Entries in the +pseudonyms+ table can be used
# to help ensure that the correct person's points are changed even when the
# sender uses a nickname or abbreviation.
#
# This class contains only the methods directly relating to IRC. Other methods
# are stored in the helper and model classes.
#
# Scorekeeper takes one custom configuration option, +scoring+, which can be
# either "open" or "closed". A closed system only allows a specified set of
# users to receive and give points. An open system allows anyone to award points
# to anyone.
#
# = Usage
#
# !points [name]:: Get a person's score
# !points [name] [+|-][number] [reason]:: Change a person's score (you must have
#                                         a "+" or a "-"). A reason is optional.
# !points [name] history:: Return some recent history of that person's score.
# !points [name] history [time period]:: Selects history from a time period.
# !points [name] history [sender]:: Selects point changes from a sender.

class Controller < Autumn::ChannelLeaf
  before_filter :authenticate, :only => [ :reload, :quit ]

  # Displays an about message.
  
  def about_command(stem, sender, reply_to, msg)
  end
  
  # Displays the current point totals, or modifies someone's score, depending on
  # the message provided with the command.
  
  def points_command(stem, sender, reply_to, msg)
    if msg.nil? or msg.empty? then
      var :totals => totals(stem, reply_to)
    elsif msg =~ /^(\w+)\s+history\s*(.*)$/ then
      parse_history stem, reply_to, $1, $2
      render :history
    elsif msg =~ /^(\w+)\s+([\+\-]\d+)\s*(.*)$/ then
      parse_change stem, reply_to, sender, $1, $2.to_i, $3
      render :change
    else
      render :usage
    end
  end
  
  private

  def authenticate_filter(stem, channel, sender, command, msg, opts)
    # Returns true if the sender has any of the privileges listed below
    not ([ :operator, :admin, :founder, :channel_owner ] & [ stem.privilege(channel, sender) ].flatten).empty?
  end
  
  def points(stem, channel)
    chan = Channel.find_or_create :server => server_identifier(stem), :name => channel
    scores = Score.all(:channel_id.eql => chan.id)
    scores.inject(Hash.new(0)) { |hsh, score| hsh[score.receiver.name] += score.change; hsh }
  end

  def totals(stem, channel)
    points(stem, channel).sort { |a,b| b.last <=> a.last }
  end

  def parse_change(stem, channel, sender, victim, delta, note)
    giver = find_person(stem, sender[:nick])
    receiver = find_person(stem, victim)
    if giver.nil? and options[:scoring] == 'open' then
      giver ||= Person.create :server => server_identifier(stem), :name => sender[:nick]
      giver.reload! # Get those default fields filled out
    end
    if receiver.nil? and options[:scoring] == 'open' then
      receiver ||= Person.create :server => server_identifier(stem), :name => find_in_channel(stem, channel, victim)
      receiver.reload! # Get those default fields filled out
    end
    unless authorized?(giver, receiver)
      var :unauthorized => true
      var :receiver => receiver.name
      return
    end
    change_points stem, channel, giver, receiver, delta, note
    var :giver => giver
    var :receiver => receiver
    var :delta => delta
  end
  
  def parse_history(stem, channel, subject, argument)
    date = argument.empty? ? nil : parse_date(argument)
    scores = Array.new
    
    chan = Channel.first(:name.eql => channel)
    person = find_person(stem, subject)
    if person.nil? then
      var :person => subject
      var :no_history => true
      return
    end
    
    if date then
      start, stop = find_range(date)
      scores = Score.all(:channel_id.eql => chan.id, :receiver_id.eql => person.id, :created_at.gte => start, :created_at.lt => stop, :order => [ :created_at.desc ])
    elsif argument.empty? then
      scores = Score.all(:channel_id.eql => chan.id, :receiver_id.eql => person.id, :order => [ :created_at.desc ])
    else
      giver = find_person(stem, argument)
      if giver.nil? then
        var :giver => argument
        var :receiver => person
        var :no_giver_history => true
        return
      end
      scores = Score.all(:channel_id.eql => chan.id, :receiver_id.eql => person.id, :giver_id => giver.id, :order => [ :created_at.desc ])
    end
    var :receiver => person
    var :giver => giver
    var :scores => scores
  end
end
