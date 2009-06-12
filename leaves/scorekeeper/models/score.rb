# A change to a people's score.

class Score
  include DataMapper::Resource
  
  property :id, Integer, :serial => true
  property :giver_id, Integer, :nullable => false, :index => :giver_and_receiver
  property :receiver_id, Integer, :nullable => false, :index => :giver_and_receiver
  property :channel_id, Integer, :nullable => false, :index => true
  property :change, Integer, :nullable => false, :default => 0
  property :note, String
  timestamps :created_at
  
  belongs_to :giver, :class_name => 'Person', :child_key => [ :giver_id ]
  belongs_to :receiver, :class_name => 'Person', :child_key => [ :receiver_id ]
  belongs_to :channel
  
  validates_with_method :cant_give_scores_to_self
  
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
  
  private
  
  def cant_give_scores_to_self
    if giver_id == receiver_id then
      [ false, "You can't change your own score." ]
    else
      true
    end
  end
end
