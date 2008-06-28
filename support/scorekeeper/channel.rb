# An IRC server and channel. The server property is of the form
# "[address]:[port]".

class Channel < DataMapper::Base
  property :server, :string, :nullable => false
  property :name, :string, :nullable => false
  
  has_many :scores
end
