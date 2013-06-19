# An IRC member who can give or receive points.

class Person
  include DataMapper::Resource
  
  property :id, Serial
  property :server, String, required: true, unique_index: :server_and_name
  property :name, String, required: true, unique_index: :server_and_name
  property :authorized, Boolean, required: true, default: true
  
  has n, :scores, child_key: [ :receiver_id ]
  has n, :scores_awarded, model: 'Score', child_key: [ :giver_id ]
  has n, :pseudonyms
end
