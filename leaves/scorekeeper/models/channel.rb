# An IRC server and channel. The server property is of the form
# "[address]:[port]".

class Channel
  include DataMapper::Resource
  
  property :id, Integer, :serial => true
  property :server, String, :nullable => false
  property :name, String, :nullable => false
  
  has n, :scores
  
  # Returns a channel by name.
  
  def self.named(name)
    all(:name => name)
  end
end
