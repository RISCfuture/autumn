# An IRC member who can give or receive points.

class Person
  include DataMapper::Resource
  
  property :id, Integer, :serial => true
  property :server, String, :nullable => false
  property :name, String, :nullable => false
  property :authorized, Boolean, :nullable => false, :default => true
  
  has n, :scores
  has n, :scores_awarded, :class_name => 'Score'
  has n, :pseudonyms
end
