require 'facets/conversion'

# Utility methods used by Scorekeeper.

module ScorekeeperHelper
  def parse_date(str)
    date = nil
    begin
      date = Chronic.parse(str, :context => :past, :guess => false)
    rescue NameError
      begin
        date = Date.parse(str)
      rescue ArgumentError
      end
    end
    return date
  end
  
  def find_range(date)
    start = nil
    stop = nil
    if date.kind_of? Range then
      start = date.first
      stop = date.last
    elsif date.kind_of? Time then
      start = date.to_date
      stop = date.to_date + 1
    else
      start = date
      stop = date + 1
    end
    return start, stop
  end
  
  def find_person(stem, nick)
    Person.each(:server.eql => server_identifier(stem)) do |person|
      return person if person.name.downcase == normalize(nick) or person.pseudonyms.collect { |pn| pn.name.downcase }.include? normalize(nick)
    end
    return nil
  end
  
  def find_in_channel(stem, channel, victim)
    stem.channel_members[channel].each do |name, privilege|
      return normalize(name, false) if normalize(name) == normalize(victim)
    end
    return victim
  end

  def normalize(nick, dc=true)
    dc ? nick.downcase.split(/\|/)[0] : nick.split(/\|/)[0]
  end
  
  def authorized?(giver, receiver)
    giver and receiver and giver.authorized? and giver.name != receiver.name
  end
  
  def change_points(stem, channel, giver, receiver, delta, note=nil)
    return if delta.zero?
    chan = Channel.find_or_create :server => server_identifier(stem), :name => channel
    chan.scores.create :giver => giver, :receiver => receiver, :change => delta, :note => note
  end
  
  def announce_change(giver, receiver, delta)
    points = (delta == 1 or delta == -1) ? 'point' : 'points'
    if delta > 0 then
      "#{giver.name} gave #{receiver.name} #{delta} #{points}."
    else
      "#{giver.name} docked #{receiver.name} #{-delta} #{points}."
    end
  end
  
  def server_identifier(stem)
    "#{stem.server}:#{stem.port}"
  end
end
