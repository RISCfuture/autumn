# A change to a people's score.

class Score
  include DataMapper::Resource
  
  property :id, Integer, :serial => true
  property :change, Integer, :nullable => false, :default => 0
  property :note, String
  property :created_at, DateTime
  
  belongs_to :giver, :class_name => 'Person', :child_key => [ :giver_id ]
  belongs_to :receiver, :class_name => 'Person', :child_key => [ :receiver_id ]
  belongs_to :channel
  
  # Returns scores given to a Person.
  
  def self.given_to(people)
    people = [ people ] unless people.kind_of?(Enumerable)
    people.map! { |person| person.kind_of?(Person) ? person.id : person }
    all(:receiver_id => people)
  end
  
  # Returns scores awarded by a Person.
  
  def self.given_by(people)
    people = [ people ] unless people.kind_of?(Enumerable)
    people.map! { |person| person.kind_of?(Person) ? person.id : person }
    all(:giver_id => people)
  end
  
  # Returns scores given between two dates.
  
  def self.between(start, stop)
    all(:created_at => start..stop)
  end
  
  # Returns scores in descending order of newness.
  
  def self.newest_first
    all(:order => [ :created_at.desc ])
  end
end
