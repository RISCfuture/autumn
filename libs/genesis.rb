require 'yaml'

Autumn::Config.version = '3.0 (7-4-08)'

module Autumn

  # Oversight class responsible for initializing the Autumn environment. To boot
  # the Autumn environment start all configured leaves, you make an instance of
  # this class and run the {#boot!} method. Leaves will each run in their own
  # thread, monitored by an oversight thread spawned by this class.

  class Genesis
    # @return [Speciator] The Speciator singleton.
    attr_reader :config

    # Creates a new instance that can be used to boot Autumn.

    def initialize
      load_pre_config_files
      @config = Speciator.instance
    end

    # Bootstraps the Autumn environment.
    #
    # @param [true, false] invoke If `true`, the leaves will be started, each in
    #   their own thread. Use `false` for console environments.

    def boot!(invoke=true)
      load_global_settings
      load_post_config_files
      load_season_settings
      load_libraries
      init_system_logger
      load_daemon_info
      load_shared_code
      load_databases
      invoke_foliater(invoke)
    end

    # Loads the settings in the `global.yml` file.
    #
    # **Prereqs**: None

    def load_global_settings
      begin
        config.global YAML.load_file(Autumn::Config.root.join('config', 'global.yml'))
      rescue SystemCallError
        raise "Couldn't find your global.yml file."
      end
      config.global root: Autumn::Config.root
      config.global season: ENV['SEASON'] if ENV['SEASON']
    end

    # Loads the files and gems that do not require an instantiated Speciator.
    #
    # **Prereqs**: None

    def load_pre_config_files
      require 'singleton'

      require 'rubygems'
      require 'bundler'
      Dir.chdir Autumn::Config.root
      Bundler.require :pre_config

      require 'facets/pathname'
      require 'active_support/dependencies/autoload'
      require 'active_support/core_ext/numeric'

      require 'libs/misc'
      require 'libs/speciator'
    end

    # Loads the files and gems that require an instantiated Speciator.
    #
    # **Prereqs**: load_global_settings

    def load_post_config_files
      require 'set'
      require 'yaml'
      require 'logger'
      require 'time'
      require 'timeout'
      require 'erb'
      require 'thread'
      require 'socket'
      require 'openssl'

      Bundler.require :default, config.global(:season).to_sym

      require 'libs/authentication'
      require 'libs/formatting'
    end

    # Loads the settings for the current season in its `season.yml` file.
    #
    # **Prereqs**: {#load_global_settings}

    def load_season_settings
      @season_dir = Autumn::Config.root.join('config', 'seasons', config.global(:season))
      raise "The current season doesn't have a directory." unless @season_dir.directory?
      begin
        config.season YAML.load_file(@season_dir.join('season.yml'))
      rescue
        # season.yml is optional
      end
    end

    # Loads Autumn library objects.
    #
    # **Prereqs**: {#load_global_settings}

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
    # **Prereqs**: {#load_libraries}

    def init_system_logger
      config.global logfile: Logger.new(log_name, config.global(:log_history) || 10, 1024*1024)
      begin
        config.global(:logfile).level = Logger.const_get(config.season(:logging).upcase)
      rescue NameError
        puts "The level #{config.season(:logging).inspect} was not understood; the log level has been raised to INFO."
        config.global(:logfile).level = Logger::INFO
      end
      config.global system_logger: LogFacade.new(config.global(:logfile), 'N/A', 'System')
      @logger = config.global(:system_logger)
    end

    # Instantiates {Daemon Daemons} from YAML files in `resources/daemons`. The
    # daemons are named after their YAML files.
    #
    # **Prereqs**: {#load_libraries}

    def load_daemon_info
      Autumn::Config.root.join('resources', 'daemons').glob('*.yml').each do |yml_file|
        yml = YAML.load_file(yml_file)
        Daemon.new yml_file.basename('.yml'), yml
      end
    end

    # Loads Ruby code in the shared directory.
    #
    # **Prereqs**: None

    def load_shared_code
      Pathname.glob(Autumn::Config.root.join('shared', '**', '*.rb')).each { |lib| load lib }
    end

    # Creates connections to databases using the DataMapper gem.
    #
    # **Prereqs**: {#load_season_settings}

    def load_databases
      db_file = @season_dir.join('database.yml')
      unless db_file.exist?
        Autumn::Config.no_database = true
        return
      end

      Bundler.require :datamapper
      require 'libs/datamapper_hacks'

      dbconfig = YAML.load_file(db_file)
      dbconfig.rekey(&:to_sym).each do |db, config|
        DataMapper.setup(db, config.kind_of?(Hash) ? config.rekey(&:to_sym) : config)
      end
    end

    # Invokes the {Foliater#load} method. Spawns a new thread to oversee the
    # stems' threads. This thread will exit when all leaves have terminated.
    #
    # **Prereqs**: {#load_databases}, {#load_season_settings},
    # {#load_libraries}, {#init_system_logger}
    #
    # @param (see #initialize)

    def invoke_foliater(invoke=true)
      begin
        begin
          stem_config = YAML.load_file(@season_dir.join('stems.yml'))
        rescue Errno::ENOENT
          raise "Couldn't find stems.yml file for season #{config.global :season}"
        end
        begin
          leaf_config = YAML.load_file(@season_dir.join('leaves.yml'))
        rescue Errno::ENOENT
          # build a default leaf config
          leaf_config = Hash.new
          Autumn::Config.root.join('leaves').glob('*').each do |dir|
            next if !dir.directory?
            leaf_name              = dir.basename.camelcase(:upper)
            leaf_config[leaf_name] = { 'class' => leaf_name }
          end
        end

        Foliater.instance.load stem_config, leaf_config, invoke
        if invoke
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
      Autumn::Config.root.join('log', config.global(:season) + '.log')
    end
  end
end
