# An IRC member who can give or receive points.

class Person
  include DataMapper::Resource
  
  property :id, Integer, :serial => true
  property :server, String, :nullable => false
  property :name, String, :nullable => false
  property :authorized, Boolean, :nullable => false, :default => true
  
  has n, :scores, :child_key => [ :receiver_id ]
  has n, :scores_awarded, :class_name => 'Score', :child_key => [ :giver_id ]
  has n, :pseudonyms
end
