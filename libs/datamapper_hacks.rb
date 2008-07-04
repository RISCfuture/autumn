# A set of hacks to make DataMapper play more nicely with classes within
# modules.

module DataMapper # :nodoc:
    
  # Hack the association models to prepend any enclosing modules to the class
  # names in associations.
  
  module Associations
    module OneToMany
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          unless class_name.include? '::'
            modules = model.to_s.split('::')
            modules.pop
            modules << class_name
            options[:class_name] = modules.join('::')
          end
          old_setup(name, model, options)
        end
      end
    end
    
    module OneToOne
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          unless class_name.include? '::'
            modules = model.to_s.split('::')
            modules.pop
            modules << class_name
            options[:class_name] = modules.join('::')
          end
          old_setup(name, model, options)
        end
      end
    end
    
    module ManyToMany
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          unless class_name.include? '::'
            modules = model.to_s.split('::')
            modules.pop
            modules << class_name
            options[:class_name] = modules.join('::')
          end
          old_setup(name, model, options)
        end
      end
    end
    
    module ManyToOne
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          unless class_name.include? '::'
            modules = model.to_s.split('::')
            modules.pop
            modules << class_name
            options[:class_name] = modules.join('::')
          end
          old_setup(name, model, options)
        end
      end
    end
  end
end
