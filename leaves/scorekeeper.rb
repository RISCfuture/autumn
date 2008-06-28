require 'data_mapper'
# Install the "chronic" gem for more robust date parsing
begin
  gem 'chronic'
  require 'chronic'
rescue Gem::LoadError
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
# are stored in ScorekeeperHelper and the model classes.
#
# = Usage
#
# !points [name]:: Get a person's score
# !points [name] [+|-][number] [reason]:: Change a person's score (you must have a "+" or
#                                         a "-"). A reason is optional.
# !points [name] history:: Return some recent history of that person's score.
# !points [name] history [time period]:: Selects history from a time period.
# !points [name] history [sender]:: Selects point changes from a sender.

class Scorekeeper < Autumn::ChannelLeaf
  # Message displayed for !about command.
  ABOUT_MESSAGE = "Scorekeeper version 2.0 (2-29-08) by Tim Morgan: An Autumn Leaf."
  # Message displayed when a user uses incorrect !points syntax.
  USAGE = %[Examples: "!points", "!points Sancho +5", "!points Smith history", "!points Sancho history 2/27/08", "!points Sancho history Smith"]
  # Set this to true if you only want a specified set of users to receive and
  # give points. Set to false if anyone should be able to award points to
  # anyone.
  CLOSED_SYSTEM = false

  before_filter :authenticate, :only => [ :reload, :quit ]

  # Displays an about message.
  
  def about_command(stem, sender, reply_to, msg)
    ABOUT_MESSAGE
  end
  
  # Displays the current point totals, or modifies someone's score, depending on
  # the message provided with the command.
  
  def points_command(stem, sender, reply_to, msg)
    if msg.nil? or msg.empty? then
      totals(stem, reply_to)
    elsif msg =~ /^(\w+)\s+history\s*(.*)$/ then
      parse_history stem, reply_to, $1, $2
    elsif msg =~ /^(\w+)\s+([\+\-]\d+)\s*(.*)$/ then
      parse_change stem, reply_to, sender, $1, $2.to_i, $3
    else
      USAGE
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
    if points(stem, channel).empty? then
      "No one has any points yet."
    else
      points(stem, channel).sort { |a,b| b.last <=> a.last }.collect { |n,p| "#{n}: #{p}" }.join(', ')
    end
  end

  def parse_change(stem, channel, sender, victim, delta, note)
    giver = find_person(stem, sender[:nick])
    receiver = find_person(stem, victim)
    if giver.nil? and not CLOSED_SYSTEM then
      giver ||= Person.create :server => server_identifier(stem), :name => sender[:nick]
      giver.reload! # Get those default fields filled out
    end
    if receiver.nil? and not CLOSED_SYSTEM then
      receiver ||= Person.create :server => server_identifier(stem), :name => find_in_channel(stem, channel, victim)
      receiver.reload! # Get those default fields filled out
    end
    return "You can't change #{victim}'s points." unless authorized?(giver, receiver)
    change_points stem, channel, giver, receiver, delta, note
    return announce_change(giver, receiver, delta)
  end
  
  def parse_history(stem, channel, subject, argument)
    date = argument.empty? ? nil : parse_date(argument)
    scores = Array.new
    
    chan = Channel.first(:name.eql => channel)
    person = find_person(stem, subject)
    return "#{subject} has no points history." unless person
    
    if date then
      start, stop = find_range(date)
      scores = Score.all(:channel_id.eql => chan.id, :receiver_id.eql => person.id, :created_at.gte => start, :created_at.lt => stop, :order => 'created_at DESC')
    elsif argument.empty? then
      scores = Score.all(:channel_id.eql => chan.id, :receiver_id.eql => person.id, :order => 'created_at DESC')
    else
      giver = find_person(stem, argument)
      return "#{argument} has not given any points." unless giver
      scores = Score.all(:channel_id.eql => chan.id, :receiver_id.eql => person.id, :giver_id => giver.id, :order => 'created_at DESC')
    end
    return "No point history found." if scores.empty?
    
    str = String.new
    if scores.size > 5 then
      str << "(#{scores.size} point changes found; showing the first 5.)\n"
      scores = scores.slice(0, 5)
    end
    scores.each { |score| str << "[#{score.created_at.strftime '%m/%d %I:%M %p'}] #{score.giver.name} #{score.change > 0 ? 'gave' : 'docked'} #{score.receiver.name} #{score.change.abs.pluralize('point')}#{score.note ? (': ' + score.note) : ''}\n"}
    return str
  end
end
