# Defines the Autumn::Genesis class, which bootstraps the Autumn environment
# and starts the Foliater.

require 'set'
require 'rubygems'
require 'active_support'
require 'yaml'
require 'logger'
require 'facets'
require 'facets/random'
require 'anise'
require 'libs/misc'
require 'libs/speciator'
require 'libs/authentication'

AUTUMN_VERSION = "3.0 (7-4-08)"

module Autumn # :nodoc:
  
  # Oversight class responsible for initializing the Autumn environment. To boot
  # the Autumn environment start all configured leaves, you make an instance of
  # this class and run the boot! method. Leaves will each run in their own
  # thread, monitored by an oversight thread spawned by this class.
  
  class Genesis # :nodoc:
    # The Speciator singleton.
    attr_reader :config
  
    # Creates a new instance that can be used to boot Autumn.
  
    def initialize
      @config = Speciator.instance
    end
    
    # Bootstraps the Autumn environment, and begins the stems' execution threads
    # if +invoke+ is set to true.
    
    def boot!(invoke=true)
      load_global_settings
      load_season_settings
      load_libraries
      init_system_logger
      load_daemon_info
      load_shared_code
      load_databases
      invoke_foliater(invoke)
    end
    
    # Loads the settings in the global.yml file.
    #
    # PREREQS: None
  
    def load_global_settings
      begin
        config.global YAML.load(File.open("#{AL_ROOT}/config/global.yml"))
      rescue SystemCallError
        raise "Couldn't find your global.yml file."
      end
      config.global :root => AL_ROOT
      config.global :season => ENV['SEASON'] if ENV['SEASON']
    end

    # Loads the settings for the current season in its season.yml file.
    #
    # PREREQS: load_global_settings
  
    def load_season_settings
      @season_dir = "#{AL_ROOT}/config/seasons/#{config.global :season}"
      raise "The current season doesn't have a directory." unless File.directory? @season_dir
      begin
        config.season YAML.load(File.open("#{@season_dir}/season.yml"))
      rescue
        # season.yml is optional
      end
    end
  
    # Loads Autumn library objects.
    #
    # PREREQS: load_global_settings

    def load_libraries
      require 'libs/inheritable_attributes'
      require 'libs/daemon'
      require 'libs/stem_facade'
      require 'libs/ctcp'
      require 'libs/stem'
      require 'libs/leaf'
      require 'libs/channel_leaf'
      require 'libs/foliater'
      require 'libs/log_facade'
    end
  
    # Initializes the system-level logger.
    #
    # PREREQS: load_libraries

    def init_system_logger
      config.global :logfile => Logger.new(log_name, config.global(:log_history) || 10, 1024*1024)
      begin
        config.global(:logfile).level = Logger.const_get(config.season(:logging).upcase)
      rescue NameError
        puts "The level #{config.season(:logging).inspect} was not understood; the log level has been raised to INFO."
        config.global(:logfile).level = Logger::INFO
      end
      config.global :system_logger => LogFacade.new(config.global(:logfile), 'N/A', 'System')
      @logger = config.global(:system_logger)
    end
    
    # Instantiates Daemons from YAML files in resources/daemons. The daemons are
    # named after their YAML files.
    #
    # PREREQS: load_libraries
    
    def load_daemon_info
      Dir.glob("#{AL_ROOT}/resources/daemons/*.yml").each do |yml_file|
        yml = YAML.load(File.open(yml_file, 'r'))
        Daemon.new File.basename(yml_file, '.yml'), yml
      end
    end
    
    # Loads Ruby code in the shared directory.
    
    def load_shared_code
      Dir.glob("#{AL_ROOT}/shared/**/*.rb").each { |lib| load lib }
    end
    
    # Creates connections to databases using the DataMapper gem.
    #
    # PREREQS: load_season_settings
    
    def load_databases
      db_file = "#{@season_dir}/database.yml"
      if not File.exist? db_file then
        $NO_DATABASE = true
        return
      end
      
      require 'dm-core'
      require 'libs/datamapper_hacks'
      
      dbconfig = YAML.load(File.open(db_file, 'r'))
      dbconfig.rekey(&:to_sym).each do |db, config|
        DataMapper.setup(db, config.kind_of?(Hash) ? config.rekey(&:to_sym) : config)
      end
    end
    
    # Invokes the Foliater.load method. Spawns a new thread to oversee the
    # stems' threads. This thread will exit when all leaves have terminated.
    # Stems will not be started if +invoke+ is set to false.
    #
    # PREREQS: load_databases, load_season_settings, load_libraries,
    # init_system_logger
    
    def invoke_foliater(invoke=true)
      begin
        begin
          stem_config = YAML.load(File.open("#{@season_dir}/stems.yml", 'r'))
        rescue Errno::ENOENT
          raise "Couldn't find stems.yml file for season #{config.global :season}"
        end
        begin
          leaf_config = YAML.load(File.open("#{@season_dir}/leaves.yml", 'r'))
        rescue Errno::ENOENT
          # build a default leaf config
          leaf_config = Hash.new
          Dir.entries("leaves").each do |dir|
            next if not File.directory? "leaves/#{dir}" or dir[0,1] == '.'
            leaf_name = dir.camelcase
            leaf_config[leaf_name] = { 'class' => leaf_name }
          end
        end
        
        Foliater.instance.load stem_config, leaf_config, invoke
        if invoke then
          # suspend execution of the master thread until all stems are dead
          while Foliater.instance.alive?
            Thread.stop
          end
        end
      rescue
        @logger.fatal $!
      end
    end
    
    private
    
    def log_name
      "#{AL_ROOT}/log/#{config.global(:season)}.log"
    end
  end
end
