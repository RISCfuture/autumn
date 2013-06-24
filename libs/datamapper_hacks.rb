# A set of hacks to make DataMapper play more nicely with classes within
# modules.

DataMapper::Repository.class_eval do # :nodoc:

  # @private
  #
  # Add a method to return all models defined for a repository.

  def models
    DataMapper::Model.descendants.select { |cl| !cl.properties(name).empty? || !cl.relationships(name).empty? }
    #HACK we are assuming that if a model has properties or relationships
    #     defined for a repository, then it must be contextual to that repo
  end
end
