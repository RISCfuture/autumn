# Miscellaneous extra methods and objects used by Autumn.

require 'thread'
require 'facets/string/case'
require 'facets/stylize'

module Kernel # :nodoc:
  
  # Bugfix for the Facets implementation of +respond+.
  
  def respond(sym, *args)
    return nil if not respond_to?(sym)
    send(sym, *args)
  end
end

class Numeric # :nodoc:
  
  # Possibly pluralizes a noun based on this number's value. Returns this number
  # and the noun as a string. This method attempts to use the Ruby English gem
  # if available, and falls back on the very simple default of appending an "s"
  # to the word to make it plural. If the Ruby English gem is not available, you
  # can specify a custom plural form for the word. Examples:
  #
  #  5.pluralize('dog') #=> "5 dogs"
  #  1.pluralize('car') #=> "1 car"
  #  7.pluralize('mouse', 'mice') #=> "7 mice" (only necessary if Ruby English is not installed)
  
  def pluralize(singular, plural=nil)
    begin
      gem 'english'
      require 'english/inflect'
      return "#{to_s} #{self == 1 ? singular : singular.plural}"
    rescue Gem::LoadError
      plural ||= singular + 's'
      return "#{to_s} #{(self == 1) ? singular : plural}"
    end
  end
end

class String # :nodoc:
  
  # Returns a copy of this string with the first character dropped.
  
  def except_first
    self[1, size-1]
  end
end

class Hash # :nodoc:
  
  # Returns a hash that gives back the key if it has no value for that key.
  
  def self.parroting(hsh={})
    hsh ||= Hash.new
    Hash.new { |h, k| k }.update(hsh)
  end
end

# An implementation of +SizedQueue+ that, instead of blocking when the queue is
# full, simply discards the overflow, forgetting it.

class ForgetfulQueue < SizedQueue # :nodoc:
  
  # Returns true if this queue is at maximum size.
  
  def full?
    size == max
  end
  
  # Pushes an object onto the queue. If there is no space left on the queue,
  # does nothing.
  
  def push(obj)
    Thread.critical = true
    return if full?
    super
  end
end
