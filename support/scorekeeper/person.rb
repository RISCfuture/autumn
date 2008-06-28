# An IRC member who can give or receive points.

class Person < DataMapper::Base
  property :server, :string, :nullable => false
  property :name, :string, :nullable => false
  property :authorized, :boolean, :nullable => false, :default => true
  
  has_many :scores, :class => 'Score', :foreign_key => 'receiver_id'
  has_many :scores_awarded, :foreign_key => 'giver_id'
  has_many :pseudonyms
end
