require 'rake'
require 'libs/genesis'

task :default do
  puts 'Type "rake --tasks" to see a list of tasks you can perform.'
end

# Load the Autumn environment.
task :environment do
  AL_ROOT = File.dirname(__FILE__)
  @genesis = Autumn::Genesis.new
  @genesis.load_global_settings
  @genesis.load_season_settings
end

task :boot do
  AL_ROOT = File.dirname(__FILE__)
  @genesis = Autumn::Genesis.new
  @genesis.boot! false
end

namespace :app do
  desc "Launch the Autumn daemon"
  task :start do
    system 'script/daemon start'
  end
  
  desc "Stop the Autumn daemon"
  task :stop do
    system 'script/daemon stop'
  end
  
  desc "Restart the Autumn daemon"
  task :restart do
    system 'script/daemon restart'
  end
  
  desc "Start Autumn but not as a daemon (stay on top)"
  task :run do
    system 'script/daemon run'
  end
  
  desc "Force the daemon to a stopped state (clears PID files)"
  task :zap do
    system 'script/daemon zap'
  end
end

namespace :log do
  desc "Remove all log files"
  task :clear do
    system 'rm -vf tmp/*.log tmp/*.output log/*.log*'
  end
  
  desc "Print all error messages in the log files"
  task :errors => :environment do
    season_log = "log/#{@genesis.config.global :season}.log"
    system_log = 'tmp/autumn.log'
    if File.exists? season_log then
      puts "==== ERROR-LEVEL LOG MESSAGES ===="
      File.open(season_log, 'r') do |log|
        puts log.grep(/^[EF],/)
      end
    end
    if File.exists? system_log then
      puts "====   UNCAUGHT EXCEPTIONS    ===="
      File.open(system_log, 'r') do |log|
        puts log.grep(/^[EF],/)
      end
    end
  end
end

def local_db?(db)
  db.host.nil? or db.host == 'localhost'
end

namespace :db do
  desc "Recreate database tables according to the model objects"
  task :migrate => :boot do
    dname = ENV['DB']
    raise "Usage: DB=[Database config name] rake db:migrate" unless dname
    raise "Unknown database config #{dname}" unless database = repository(dname.to_sym)
    puts "Migrating the #{dname} database..."
    # Find models that have definitions for the selected database and migrate them
    repository(dname.to_sym) do
      repository(dname.to_sym).models.each { |mod| mod.auto_migrate! dname.to_sym }
    end
  end
  desc "Nondestructively update database tables according to the model objects"
  task :upgrade => :boot do
    dname = ENV['DB']
    raise "Usage: DB=[Database config name] rake db:upgrade" unless dname
    raise "Unknown database config #{dname}" unless database = repository(dname.to_sym)
    puts "Upgrading the #{dname} database..."
    # Find models that have definitions for the selected database and upgrade them
    repository(dname.to_sym) do
      repository(dname.to_sym).models.each { |mod| mod.auto_upgrade! dname.to_sym }
    end
  end
end

namespace :doc do
  desc "Generate API documentation for Autumn"
  task :api => :environment do
    FileUtils.remove_dir 'doc/api' if File.directory? 'doc/api'
    system "rdoc --main README --title 'Autumn API Documentation' -o doc/api --line-numbers --inline-source libs README"
  end
  
  desc "Generate documentation for all leaves"
  task :leaves => :environment do
    FileUtils.remove_dir 'doc/leaves' if File.directory? 'doc/leaves'
    Dir.glob("leaves/*").each do |leaf_dir|
      Dir.chdir leaf_dir do
        system "rdoc --main README --title '#{File.basename(leaf_dir).camelcase} Documentation' -o ../../doc/leaves/#{File.basename leaf_dir} --line-numbers --inline-source controller.rb helpers models README"
      end
    end
  end
  
  desc "Remove all documentation"
  task :clear => :environment do
    FileUtils.remove_dir 'doc/api' if File.directory? 'doc/api'
    FileUtils.remove_dir 'doc/leaves' if File.directory? 'doc/leaves'
  end
end

# Load any custom Rake tasks in the bot's tasks directory.
Dir["leaves/*"].each do |leaf|
  leaf_name = File.basename(leaf, ".rb").downcase
  namespace leaf_name.to_sym do # Tasks are placed in a namespace named after the leaf
    FileList["leaves/#{leaf_name}/tasks/**/*.rake"].sort.each do |task|
      load task
    end
  end
end
