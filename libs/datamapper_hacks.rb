# A set of hacks to make DataMapper play more nicely with classes within
# modules.

module DataMapper # :nodoc:
    
  #HACK Add module names to auto-generated class names in relationships
  #
  # When a class name is automatically inferred from a relationship name (e.g.,
  # guessing that has_many :widgets refers to a Widget class), it is necessary
  # to enclose these class names in the same modules as the calling class. For
  # example, if MyLeaf::Factory has_many :widgets, this hack will ensure the
  # inferred class name is MyLeaf::Widget, instead of just ::Widget.
  #
  # This hack is performed for each of the association types in DataMapper. An
  # :old_behavior option is given to revert to the unhacked method.
  
  module Associations # :nodoc:
    module OneToMany # :nodoc:
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          if not options[:old_behavior] and not class_name.include?('::') then
            modules = model.to_s.split('::')
            modules.pop
            modules << class_name
            options[:class_name] = modules.join('::')
          end
          old_setup(name, model, options)
        end
      end
    end
     
    module OneToOne # :nodoc:
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          if not options[:old_behavior] and not class_name.include?('::') then
            modules = model.to_s.split('::')
            modules.pop
            modules << class_name
            options[:class_name] = modules.join('::')
          end
          old_setup(name, model, options)
        end
      end
    end
        
    module ManyToOne # :nodoc:
      class << self
        alias_method :old_setup, :setup
        def setup(name, model, options={})
          class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
          if not options[:old_behavior] and not class_name.include?('::') then
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

#HACK Strip module names when auto-generating table names for has-many-through
#     relationships.
#
# By default, DataMapper will not strip module names when creating the join
# tables for has-many-through relationships. So, if MyLeaf::Post has and belongs
# to many MyLeaf::Category, the join table will be called
# "my_leaf/categories_my_leaf/posts", which is clearly an invalid table name.
# This hack strips module components from a class name before generating the
# join table's name.
#
# A side effect of this hack is that no two DataMapper models for the same
# repository can share the same name, even if they are in separate modules.
#
# This also fixes a bug that can occur when script/console is launched. The
# double assignment of the relationship variable seems to mess up IRb, so it has
# been split into two assignments.

DataMapper::Associations::ManyToMany.module_eval do # :nodoc:
  def self.setup(name, model, options={})
    class_name = options.fetch(:class_name, Extlib::Inflection.classify(name))
    if not options[:old_behavior] and not class_name.include?('::') then
      modules = model.to_s.split('::')
      modules.pop
      modules << class_name
      options[:class_name] = modules.join('::')
    end
    
    assert_kind_of 'name',    name,    Symbol
    assert_kind_of 'model',   model,   DataMapper::Model
    assert_kind_of 'options', options, Hash

    repository_name = model.repository.name

    model.class_eval <<-EOS, __FILE__, __LINE__
      def #{name}(query = {})
        #{name}_association.all(query)
      end

      def #{name}=(children)
        #{name}_association.replace(children)
      end

      private

      def #{name}_association
        @#{name}_association ||= begin
          unless relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]
            raise ArgumentError, "Relationship #{name.inspect} does not exist in \#{model}"
          end
          association = Proxy.new(relationship, self)
          parent_associations << association
          association
        end
      end
    EOS

    opts = options.dup
    opts.delete(:through)
    opts[:child_model]              ||= opts.delete(:class_name)  || Extlib::Inflection.classify(name)
    opts[:parent_model]             =   model
    opts[:repository_name]          =   repository_name
    opts[:remote_relationship_name] ||= opts.delete(:remote_name) || name
    opts[:parent_key]               =   opts[:parent_key]
    opts[:child_key]                =   opts[:child_key]
    opts[:mutable]                  =   true

    names        = [ opts[:child_model].demodulize, opts[:parent_model].name.demodulize ].sort
    model_name   = names.join
    storage_name = Extlib::Inflection.tableize(Extlib::Inflection.pluralize(names[0]) + names[1])
    model_module = model.to_s.split('::')
    model_module.pop
    model_module = model_module.join('::')
    

    opts[:near_relationship_name] = Extlib::Inflection.tableize(model_name).to_sym

    model.has(model.n, opts[:near_relationship_name], :old_behavior => true)

    relationship = DataMapper::Associations::RelationshipChain.new(opts)
    model.relationships(repository_name)[name] = relationship

    unless Object.const_defined?(model_name)
      bts = names.collect do |name|
        "belongs_to #{Extlib::Inflection.underscore(name).to_sym.inspect}"
      end
      
      Object.const_get(model_module).module_eval <<-EOS, __FILE__, __LINE__
        class #{model_name}
          include DataMapper::Resource
          
          #def self.name; #{model_name.inspect} end
          #def self.default_repository_name; #{repository_name.inspect} end
          def self.many_to_many; true end
          
          storage_names[#{repository_name.inspect}] = #{storage_name.inspect}
          
          #{bts.join("\n")}
        end
      EOS
    end

    relationship
  end
end

#HACK Update methods in RelationshipChain to use the scoped repository.
#
# This hack will update methods to use the currently-scoped repository, instead
# of always using the default repository.

module DataMapper # :nodoc:
  module Associations # :nodoc:
    class RelationshipChain # :nodoc:
      def near_relationship
        parent_model.relationships(repository.name)[@near_relationship_name]
      end
  
      def remote_relationship
        near_relationship.child_model.relationships(repository.name)[@remote_relationship_name] ||
          near_relationship.child_model.relationships(repository.name)[@remote_relationship_name.to_s.singularize.to_sym]
      end
    end
  end
end

DataMapper::Model.class_eval do
  
  #HACK Determine the child key from the given repository, not the default one.
  #
  # Updates this method to use the hacked child_key method.
  
  def properties_with_subclasses(repository_name = default_repository_name)
    properties = DataMapper::PropertySet.new
    ([ self ].to_set + (respond_to?(:descendants) ? descendants : [])).each do |model|
      model.relationships(repository_name).each_value { |relationship| relationship.child_key(repository_name) }
      model.many_to_one_relationships.each do |relationship| relationship.child_key(repository_name) end
      model.properties(repository_name).each do |property|
        properties << property unless properties.has_property?(property.name)
      end
    end
    properties
  end
end

DataMapper::Associations::Relationship.class_eval do
  
  #HACK Determine the child key from the given repository, not the default one.
  #
  # Updates this method to take a repository name. The child key will be
  # determined from the properties scoped to the given repository.
  #
  # The @child_key class variable is changed to a hash that maps repository
  # names to the appropriate key.
  
  def child_key(repository_name=nil)
    repository_name ||= repository.name
    @child_key ||= Hash.new
    @child_key[repository_name] ||= begin
      model_properties = child_model.properties(repository_name)

      child_key = parent_key(repository_name).zip(@child_properties || []).map do |parent_property,property_name|
        # TODO: use something similar to DM::NamingConventions to determine the property name
        parent_name = Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model.base_model.name))
        property_name ||= "#{parent_name}_#{parent_property.name}".to_sym

        if model_properties.has_property?(property_name)
          model_properties[property_name]
        else
          options = {}

          [ :length, :precision, :scale ].each do |option|
            options[option] = parent_property.send(option)
          end

          # NOTE: hack to make each many to many child_key a true key,
          # until I can figure out a better place for this check
          if child_model.respond_to?(:many_to_many)
            options[:key] = true
          end

          child_model.property(property_name, parent_property.primitive, options)
        end
      end
      DataMapper::PropertySet.new(child_key)
    end
    return @child_key[repository_name]
  end
  
  #HACK Determine the parent key from the given repository, not the default one.
  #
  # Updates this method to take a repository name. The parent key will be
  # determined from the properties scoped to the given repository.
  #
  # The @parent_key class variable is changed to a hash that maps repository
  # names to the appropriate key.
  
  def parent_key(repository_name=nil)
    repository_name ||= repository.name
    @parent_key ||= Hash.new
    @parent_key[repository_name] ||= begin
      parent_key = if @parent_properties
        parent_model.properties(repository_name).slice(*@parent_properties)
      else
        parent_model.key(repository_name)
      end
      DataMapper::PropertySet.new(parent_key)
    end
    return @parent_key[repository_name]
  end
end

# Add a method to return all models defined for a repository.

DataMapper::Repository.class_eval do
  def models
    DataMapper::Resource.descendants.select { |cl| not cl.properties(name).empty? or not cl.relationships(name).empty? }
    #HACK we are assuming that if a model has properties or relationships
    #     defined for a repository, then it must be contextual to that repo
  end
end
