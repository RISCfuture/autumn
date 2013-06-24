# Miscellaneous extra methods and objects used by Autumn, and additions to Ruby
# Core objects.

# @private
class Numeric

  # Possibly pluralizes a noun based on this number's value. Returns this number
  # and the noun as a string. This method attempts to use the Ruby English gem
  # if available, and falls back on the very simple default of appending an "s"
  # to the word to make it plural. If the Ruby English gem is not available, you
  # can specify a custom plural form for the word. Examples:
  #
  # 5.pluralize('dog') #=> "5 dogs"
  # 1.pluralize('car') #=> "1 car"
  # 7.pluralize('mouse', 'mice') #=> "7 mice" (only necessary if Ruby English is not installed)

  def pluralize(singular, plural=nil)
    begin
      return "#{to_s} #{self == 1 ? singular : singular.plural}"
    rescue Gem::LoadError
      plural ||= singular + 's'
      return "#{to_s} #{(self == 1) ? singular : plural}"
    end
  end
end

# @private
class String

  # Returns a copy of this string with the first character dropped.

  def except_first
    self[1, size-1]
  end

  # Removes modules from a full class name.

  def demodulize
    split("::").last
  end
end

# @private
class Hash

  # Returns a hash that gives back the key if it has no value for that key.

  def self.parroting(hsh={})
    hsh ||= Hash.new
    Hash.new { |h, k| k }.update(hsh)
  end
end

# @private
#
# An implementation of `SizedQueue` that, instead of blocking when the queue is
# full, simply discards the overflow, forgetting it.

class ForgetfulQueue < Queue

  # Creates a new sized queue.

  def initialize(capacity)
    super()
    @max = capacity
    @mutex = Mutex.new
  end

  # Returns true if this queue is at maximum size.

  def full?
    size == @max
  end

  # Pushes an object onto the queue. If there is no space left on the queue,
  # does nothing.

  def push(obj)
    super unless full?
  end
  alias_method :<<, :push
  alias_method :enq, :push
end

# @private Adds the only method to Set.

class Set

  # Returns the only element of a one-element set. Raises an exception if there
  # isn't exactly one element in the set.

  def only
    raise IndexError, "Set#only called on non-single-element set" unless size == 1
    to_a.first
  end
end
