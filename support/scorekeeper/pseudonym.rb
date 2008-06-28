# A person's nickname. If someone changes a person's points using this nickname,
# the correct Person instance has their points changed.

class Pseudonym < DataMapper::Base
  property :name, :string, :nullable => false
  
  belongs_to :person
end
