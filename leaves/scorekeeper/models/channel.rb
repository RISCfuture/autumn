# An IRC server and channel. The server property is of the form
# "[address]:[port]".
#
# Associations
# ------------
#
# | `scores` | The {Score Scores} awarded on this channel. |
#
# Properties
# ----------
#
# | `server` | The address of the server this channel is on. |
# | `name` | The name of this channel, including the "#". |

class Channel
  include DataMapper::Resource

  property :id, Serial
  property :server, String, key: true
  property :name, String, key: true

  has n, :scores

  # Finds a channel by name.
  #
  # @param [String] name A channel name.
  # @return [Array<Channel>] The channels with that name.

  def self.named(name)
    all(name: name)
  end
end
