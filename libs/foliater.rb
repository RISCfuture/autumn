# Defines the Autumn::Foliater class, which instantiates stems and leaves and
# keeps watch over their threads.

module Autumn

  # Loads Stems and Leaves and executes them in their own threads. Manages the
  # threads and oversees all leaves. This is a singleton class.

  class Foliater
    include Singleton
  
    # The Speciator singleton.
    attr_reader :config
    # A hash of all Stem instances by their config names.
    attr_reader :stems
    # A hash of all Leaf instances by their config names.
    attr_reader :leaves
  
    def initialize # :nodoc:
      @config = Speciator.instance
      @stems = Hash.new
      @leaves = Hash.new
      @ctcp = Autumn::CTCP.new
    end
    
    # Loads the config files and their classes, initializes all stems and leaves
    # and begins the stems' execution processes in their own threads. You must
    # pass the stem and leaf config hashes (from the stems.yml and leaves.yml
    # files).
    #
    # If +invoke+ is set to false, start_stems will not be called.
    
    def load(stem_config, leaf_config, invoke=true)
      load_configs stem_config, leaf_config
      load_leaf_classes
      load_leaves
      load_all_leaf_models
      load_stems
      start_stems if invoke
    end
    
    # Reloads a leaf while it is running. Re-opens class definition files and
    # runs them to redefine the classes. Does not work exactly as it should,
    # but well enough for a rough hot-reload capability.
    
    def hot_reload(leaf)
      type = leaf.class.to_s.split('::').first
      load_leaf_libs type
      load_leaf_controller type
      load_leaf_helpers type
      load_leaf_models leaf
      load_leaf_views type
    end

    # Returns true if there is at least one stem still running.
  
    def alive?
      @stem_threads and @stem_threads.any? { |name, thread| thread.alive? }
    end
    
    # This method yields each Stem that was loaded, allowing you to iterate over
    # each stem. For instance, to take attendance:
    #
    #  Foliater.instance.each_stem { |stem| stem.message "Here!" }
  
    def each_stem
      @leaves.each { |leaf| yield leaf }
    end

    # This method yields each Leaf subclass that was loaded, allowing you to
    # iterate over each leaf. For instance, to take attendance:
    #
    #  Foliater.instance.each_leaf { |leaf| leaf.stems.message "Here!" }
  
    def each_leaf
      @leaves.each { |leaf| yield leaf }
    end

    private
    
    def load_configs(stem_config, leaf_config)
      leaf_config.each do |name, options|
        global_config_file = "#{AL_ROOT}/leaves/#{options['class'].snakecase}/config.yml"
        if File.exist? global_config_file then
          config.leaf name, YAML.load(File.open(global_config_file))
        end
        config.leaf name, options
        config.leaf name, :logger => LogFacade.new(config.global(:logfile), 'Leaf', name)
      end
      stem_config.each do |name, options|
        config.stem name, options
        config.stem name, :logger => LogFacade.new(config.global(:logfile), 'Stem', name)
      end
    end
    
    def load_leaf_classes
      config.all_leaf_classes.each do |type|
        Object.class_eval "module #{type}; end"
        
        config.leaf type, :module => Object.const_get(type)
        
        load_leaf_libs type
        load_leaf_controller(type)
        load_leaf_helpers(type)
        load_leaf_views(type)
      end
    end
    
    def load_leaf_controller(type)
      controller_file = "#{AL_ROOT}/leaves/#{type.snakecase}/controller.rb"
      raise "controller.rb file for leaf #{type} not found" unless File.exist? controller_file
      controller_code = nil
      begin
        File.open("#{AL_ROOT}/leaves/#{type.snakecase}/controller.rb", 'r') { |f| controller_code = f.read }
      rescue Errno::ENOENT
        raise "controller.rb file for leaf #{type} not found"
      end
      config.leaf(type, :module).module_eval controller_code
    end
    
    def load_leaf_helpers(type)
      mod = config.leaf(type, :module)
      helper_code = nil
      Dir.glob("#{AL_ROOT}/leaves/#{type.snakecase}/helpers/*.rb").each do |helper_file|
        File.open(helper_file, 'r') { |f| helper_code = f.read }
        mod.module_eval helper_code
      end
      
      leaf_class = nil
      begin
        leaf_class = mod.const_get('Controller')
      rescue NameError
        raise NameError, "Couldn't find Controller class for leaf #{type}"
      end
      
      config.leaf type, :helpers => Set.new
      mod.constants.select { |const_name| const_name =~ /Helper$/ }.map { |helper_name| mod.const_get helper_name }.each do |helper|
        config.leaf(type, :helpers) << helper
      end
    end
    
    def load_leaf_libs(type)
      Dir.glob("#{AL_ROOT}/leaves/#{type.snakecase}/lib/*.rb").each  { |lib_file| require lib_file }
    end
    
    def load_leaf_views(type)
      views = Hash.new
      view_text = nil
      Dir.glob("#{AL_ROOT}/leaves/#{type.snakecase}/views/*.txt.erb").each do |view_file|
        view_name = File.basename(view_file).match(/^(.+)\.txt\.erb$/)[1]
        File.open(view_file, 'r') { |f| view_text = f.read }
        views[view_name] = view_text
      end
      config.leaf type, :views => views
    end
    
    def load_leaves
      config.each_leaf do |name, options|
        options = config.options_for_leaf(name)
        options[:root] = "#{config.global :root}/leaves/#{options[:class].snakecase}"
        begin
          leaf_class = options[:module].const_get('Controller')
        rescue NameError
          raise NameError, "Couldn't find Controller class for leaf #{name}"
        end
        @leaves[name] = leaf_class.new(options)
        formatter = Autumn::Formatting.const_get options[:formatter].to_sym if options[:formatter] and (Autumn::Formatting.constants.include? options[:formatter] or Autumn::Formatting.constants.include? options[:formatter].to_sym)
        formatter ||= Autumn::Formatting::DEFAULT
        @leaves[name].extend formatter
        options[:helpers].each { |helper| @leaves[name].extend helper }
        # extend the formatter first so helper methods override its methods if necessary
      end
    end
    
    def load_all_leaf_models
      @leaves.each { |name, instance| load_leaf_models instance }
    end
    
    def load_leaf_models(leaf)
      model_code = nil
      mod = config.leaf(leaf.options[:class], :module)
      leaf.database do
        Dir.glob("#{AL_ROOT}/leaves/#{leaf.options[:class].snakecase}/models/*.rb").each do |model_file|
          File.open(model_file, 'r') { |f| model_code = f.read }
          mod.module_eval model_code
        end
        # Need to manually set the table names of the models because we loaded
        # them inside a module
        unless $NO_DATABASE
          mod.constants.map { |const_name| mod.const_get(const_name) }.select { |const| const.ancestors.include? DataMapper::Resource }.each do |model|
            model.storage_names[leaf.database_name] = model.to_s.demodulize.snakecase.pluralize
          end
        end
      end
    end
    
    def load_stems
      config.each_stem do |name, options|
        options = config.options_for_stem(name)
        server = options[:server]
        nick = options[:nick]
        
        @stems[name] = Stem.new(server, nick, options)
        leaves = options[:leaves]
        leaves ||= [ options[:leaf] ]
        leaves.each do |leaf|
          raise "Unknown leaf #{leaf} in configuration for stem #{name}" unless @leaves[leaf]
          @stems[name].add_listener @leaves[leaf]
          @stems[name].add_listener @ctcp
          #TODO a configurable way of specifying listeners to add by default
          @leaves[leaf].stems << @stems[name]
        end
      end
    end
    
    def start_stems
      @leaves.each { |name, leaf| leaf.preconfigure }
      @leaves.each { |name, leaf| leaf.will_start_up }
      @stem_threads = Hash.new
      config.each_stem do |name, options|
        @stem_threads[name] = Thread.new(@stems[name], Thread.current) do |stem, parent_thread|
          # The thread will run the stem until it exits, then inform the main
          # thread that it has exited. When the main thread wakes, it checks if
          # all stems have terminated; if so, it terminates itself.
          begin
            stem.start
          rescue
            options[:logger].fatal $!
          ensure
            parent_thread.wakeup # Schedule the parent thread to wake up after this thread finishes
          end
        end
      end
    end
    
  end
end
