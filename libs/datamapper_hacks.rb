# A set of hacks to make DataMapper play more nicely with classes within
# modules.

module DataMapper # :nodoc:
    
  # Hack the association models to prepend any enclosing modules to the class
  # names in associations.
  
  module Associations
    module OneToMany
      alias_method :old_one_to_many, :one_to_many
      def one_to_many(name, options={})
        class_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))
        unless class_name.include? '::'
          modules = self.to_s.split('::')
          modules.pop
          modules << class_name
          options[:class_name] = modules.join('::')
        end
        old_one_to_many(name, options)
      end
    end
    
    module OneToOne
      alias_method :old_one_to_one, :one_to_one
      def one_to_one(name, options={})
        class_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))
        unless class_name.include? '::'
          modules = self.to_s.split('::')
          modules.pop
          modules << class_name
          options[:class_name] = modules.join('::')
        end
        old_one_to_one(name, options)
      end
    end
    
    module ManyToMany
      alias_method :old_many_to_many, :many_to_many
      def many_to_many(name, options={})
        class_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))
        unless class_name.include? '::'
          modules = self.to_s.split('::')
          modules.pop
          modules << class_name
          options[:class_name] = modules.join('::')
        end
        old_many_to_many(name, options)
      end
    end
    
    module ManyToOne
      alias_method :old_many_to_one, :many_to_one
      def many_to_one(name, options={})
        class_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))
        unless class_name.include? '::'
          modules = self.to_s.split('::')
          modules.pop
          modules << class_name
          options[:class_name] = modules.join('::')
        end
        old_many_to_one(name, options)
      end
    end
  end
end
