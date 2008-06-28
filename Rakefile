require 'rake'
require 'facets/symbol/to_proc'
require 'facets/stylize'
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

task :full_bootstrap do
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
    system_log = 'tmp/autumn-leaves.log'
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
  desc "Create a database"
  task :create => :full_bootstrap do
    lname = ENV['LEAF']
    raise "Usage: LEAF=[Leaf name] rake db:populate" unless lname
    raise "Unknown leaf #{lname}" unless leaf = Autumn::Foliater.instance.leaves[lname]
    raise "No databases configured" unless File.exist? "config/seasons/#{@genesis.config.global :season}/database.yml"
    db = DataMapper::Database[leaf.database_name]
    raise "No database configured for #{lname}" unless db
    
    case db.adapter.class.to_s
      when 'DataMapper::Adapters::MysqlAdapter'
        `echo "CREATE DATABASE #{db.database} CHARACTER SET utf8" | mysql -u#{db.username} -h#{db.host} -p#{db.password}`
      when 'DataMapper::Adapters::PostgresqlAdapter'
        local_db?(db) ? `createdb "#{db.database}" -E utf8` : raise("Can only create local PostgreSQL databases")
      when 'DataMapper::Adapters::Sqlite3Adapter'
        `sqlite3 "#{db.database}"`
    end
  end
  
  desc "Drop a database"
  task :drop => :full_bootstrap do
    lname = ENV['LEAF']
    raise "Usage: LEAF=[Leaf name] rake db:populate" unless lname
    raise "Unknown leaf #{lname}" unless leaf = Autumn::Foliater.instance.leaves[lname]
    raise "No databases configured" unless File.exist? "config/seasons/#{@genesis.config.global :season}/database.yml"
    db = DataMapper::Database[leaf.database_name]
    raise "No database configured for #{lname}" unless db
    
    case db.adapter.class.to_s
      when 'DataMapper::Adapters::MysqlAdapter'
        `echo "DROP DATABASE #{db.database}" | mysql -u#{db.username} -h#{db.host} -p#{db.password}`
      when 'DataMapper::Adapters::PostgresqlAdapter'
        local_db?(db) ? `dropdb "#{db.database}"` : raise("Can only drop local PostgreSQL databases")
      when 'DataMapper::Adapters::Sqlite3Adapter'
        FileUtils.rm_f db.database
    end
  end
  
  desc "Create database tables according to the model objects"
  task :populate => :full_bootstrap do
    lname = ENV['LEAF']
    raise "Usage: LEAF=[Leaf name] rake db:populate" unless lname
    raise "Unknown leaf #{lname}" unless leaf = Autumn::Foliater.instance.leaves[lname]
    
    leaf.database do
      Dir.glob("support/#{leaf.class.pathize}/**/*.rb").each do |file|
        content = nil
        File.open(file, 'r') { |f| content = f.read }
        content.scan(/class ([A-Z]\w+)/).flatten.each do |cname|
          klass = Module.const_get(cname.to_sym)
          next unless klass.ancestors.map(&:to_s).include? 'DataMapper::Base'
          puts "Creating table for #{cname}..."
          klass.table.create!
        end
      end
    end
  end
  
  desc "Drop, recreates, and repopulates a database"
  task :reset => [ 'db:drop', 'db:create', 'db:populate' ]
end

namespace :doc do
  desc "Generate API documentation for Autumn"
  task :api => [ :environment, :clear ] do
    system 'rm -rf doc/api' if File.directory? 'doc/api'
    system "rdoc --main README --title 'Autumn API Documentation' -o doc/api --line-numbers --inline-source libs README"
  end
  
  desc "Generate documentation for all leaves"
  task :leaves => [ :environment, :clear ] do
    system 'rm -rf doc/leaves' if File.directory? 'doc/leaves'
    system "rdoc --main README --title 'Autumn Leaves Documentation' -o doc/leaves --line-numbers --inline-source leaves support"
  end
  
  desc "Remove all documentation"
  task :clear => :environment do
    system 'rm -rf doc/api' if File.directory? 'doc/api'
    system 'rm -rf doc/leaves' if File.directory? 'doc/leaves'
  end
end
