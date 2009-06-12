# A person's nickname. If someone changes a person's points using this nickname,
# the correct Person instance has their points changed.

class Pseudonym
  include DataMapper::Resource
  
  property :id, Integer, :serial => true
  property :name, String, :nullable => false, :index => true
  property :person_id, Integer, :nullable => false, :index => true
  
  belongs_to :person
end
