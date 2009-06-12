require 'dm-validations'
require 'dm-timestamps'

DataMapper::Timestamp.class_eval do
  private
  
  #HACK Use the current repository, not the default one.
  #
  # Updates this method to use the currently-scoped repository rather than the
  # model's default repository.
  
  def set_timestamps
    return unless dirty? || new_record?
    TIMESTAMP_PROPERTIES.each do |name,(_type,proc)|
      if model.properties(repository.name).has_property?(name)
        model.properties(repository.name)[name].set(self, proc.call(self, model.properties(repository.name)[name])) unless attribute_dirty?(name)
      end
    end
  end
end
