# # A set of hacks to make DataMapper play more nicely with classes within
# # modules.

# Add a method to return all models defined for a repository.

DataMapper::Repository.class_eval do
  def models
    DataMapper::Model.descendants.select { |cl| not cl.properties(name).empty? or not cl.relationships(name).empty? }
    #HACK we are assuming that if a model has properties or relationships
    #     defined for a repository, then it must be contextual to that repo
  end
end
