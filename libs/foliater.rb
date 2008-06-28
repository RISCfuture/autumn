require 'yaml'
require 'singleton'
require 'facets/stylize'

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
      load_leaf_support_classes
      load_stems
      start_stems if invoke
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
        config.leaf name, options
        config.leaf name, :logger => LogFacade.new(config.global(:logfile), 'Leaf', name)
      end
      stem_config.each do |name, options|
        config.stem name, options
        config.stem name, :logger => LogFacade.new(config.global(:logfile), 'Stem', name)
      end
    end
    
    def load_leaf_classes
      config.all_leaf_classes.each { |type| require "leaves/#{type.pathize}.rb" }
    end
    
    def load_leaves
      config.each_leaf do |name, options|
        options = config.options_for_leaf(name)
        begin
          leaf_class = Module.const_get(options[:class])
        rescue NameError
          raise NameError, "Couldn't find class #{options[:class]} for leaf #{name}"
        end
        @leaves[name] = leaf_class.new(options)
        formatter = Autumn::Formatting.const_get options[:formatter].to_sym if options[:formatter] and (Autumn::Formatting.constants.include? options[:formatter] or Autumn::Formatting.constants.include? options[:formatter].to_sym)
        formatter ||= Autumn::Formatting::DEFAULT
        @leaves[name].extend formatter
      end
    end
    
    def load_leaf_support_classes
      @leaves.each do |name, leaf|
        leaf.database do
          begin
            require "support/#{leaf.class.pathize}.rb"
          rescue LoadError
            # support file is optional
          end
          Dir.glob("support/#{leaf.class.pathize}/**/*.rb").each { |helper_file| require helper_file }
        end
        Module.constants.select { |cname| cname =~ /^#{leaf.options[:class]}.*Helper$/ }.each do |mname|
          mod = Module.const_get(mname)
          leaf.extend mod
        end
      end
    end
    
    def load_stems
      config.each_stem do |name, options|
        options = config.options_for_stem(name)
        server = options.delete(:server)
        nick = options.delete(:nick)
        
        @stems[name] = Stem.new(server, nick, options)
        leaves = options[:leaves]
        leaves ||= [ options[:leaf] ]
        leaves.each do |leaf|
          raise "Unknown leaf #{leaf} in configuration for stem #{name}" unless @leaves[leaf]
          @stems[name].add_listener @leaves[leaf]
          @stems[name].add_listener @ctcp
          #TODO a configurable way of specifying listeners to add by default
          @stems[name].leaves << @leaves[leaf]
          @leaves[leaf].stems << @stems[name]
        end
      end
    end
    
    def start_stems
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
