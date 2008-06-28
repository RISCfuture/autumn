# A change to a person's score.

class Score < DataMapper::Base
  property :change, :integer, :nullable => false, :default => 0
  property :note, :string
  property :created_at, :datetime
  
  belongs_to :giver, :class => 'Person'
  belongs_to :receiver, :class => 'Person'
  belongs_to :channel
end
