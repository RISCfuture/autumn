require 'bundler'
Bundler.require :pre_config, :default, :documentation

require 'rake'
require 'pathname'
require 'facets/pathname'

$: << Dir.getwd
require 'libs/autumn'
$: << Autumn::Config.root.to_s unless Autumn::Config.root.to_s == Dir.getwd
require 'libs/genesis'

task :default do
  puts 'Type "rake --tasks" to see a list of tasks you can perform.'
end

# Load the Autumn environment.
task :environment do
  @genesis = Autumn::Genesis.new
  @genesis.load_global_settings
  @genesis.load_season_settings
end

task :boot do
  @genesis = Autumn::Genesis.new
  @genesis.boot! false
end

namespace :app do
  desc "Launch the Autumn daemon"
  task :start do
    system 'script/daemon', 'start'
  end

  desc "Stop the Autumn daemon"
  task :stop do
    system 'script/daemon', 'stop'
  end

  desc "Restart the Autumn daemon"
  task :restart do
    system 'script/daemon', 'restart'
  end

  desc "Start Autumn but not as a daemon (stay on top)"
  task :run do
    system 'script/daemon', 'run'
  end

  desc "Force the daemon to a stopped state (clears PID files)"
  task :zap do
    system 'script/daemon', 'zap'
  end
end

namespace :log do
  desc "Remove all log files"
  task :clear do
    system 'rm', '-vf', 'tmp/*.log', 'tmp/*.output', 'log/*.log*'
  end

  desc "Print all error messages in the log files"
  task :errors do
    season_log = Pathname.new('log').join(@genesis.config.global(:season), 'log')
    system_log = Pathname.new('tmp').join('autumn.log')
    if season_log.exist?
      puts "==== ERROR-LEVEL LOG MESSAGES ===="
      File.open(season_log, 'r') do |log|
        puts log.grep(/^[EF],/)
      end
    end
    if system_log.exist?
      puts "====   UNCAUGHT EXCEPTIONS    ===="
      File.open(system_log, 'r') do |log|
        puts log.grep(/^[EF],/)
      end
    end
  end
end

def local_db?(db)
  db.host.nil? || db.host == 'localhost'
end

namespace :db do
  desc "Recreate database tables according to the model objects"
  task migrate: :boot do
    dname = ENV['DB']
    raise "Usage: DB=[Database config name] rake db:migrate" unless dname
    raise "Unknown database config #{dname}" unless repository(dname.to_sym)
    puts "Migrating the #{dname} database..."
    # Find models that have definitions for the selected database and migrate them
    repository(dname.to_sym) do
      repository(dname.to_sym).models.each { |mod| mod.auto_migrate! dname.to_sym }
    end
  end
  desc "Nondestructively update database tables according to the model objects"
  task upgrade: :boot do
    dname = ENV['DB']
    raise "Usage: DB=[Database config name] rake db:upgrade" unless dname
    raise "Unknown database config #{dname}" unless repository(dname.to_sym)
    puts "Upgrading the #{dname} database..."
    # Find models that have definitions for the selected database and upgrade them
    repository(dname.to_sym) do
      repository(dname.to_sym).models.each { |mod| mod.auto_upgrade! dname.to_sym }
    end
  end
end

# bring sexy back (sexy == tables)
module YARD::Templates::Helpers::HtmlHelper
  def html_markup_markdown(text)
    markup_class(:markdown).new(text, :gh_blockcode, :fenced_code, :autolink, :tables).to_html
  end
end

namespace :doc do
  desc "Generate API documentation for Autumn"
  YARD::Rake::YardocTask.new(:api) do |doc|
    api_doc = Pathname.new('doc').join('api')
    FileUtils.mkdir_p api_doc unless api_doc.directory?

    doc.options << '-m' << 'markdown' << '-M' << 'redcarpet'
    doc.options << '--protected' << '--no-private'
    doc.options << '-r' << 'README.md'
    doc.options << '-o' << api_doc.to_s
    doc.options << '--title' << "Autumn API Documentation"

    doc.files = %w( libs/**/*.rb README.md )
  end

  leaf_names_and_dirs = Pathname.new('leaves').glob('*').inject({}) do |hsh, path|
    leaf_dir       = path.realpath
    leaf_name      = leaf_dir.basename.to_s.camelcase(:upper)
    hsh[leaf_name] = leaf_dir
    hsh
  end

  leaf_names_and_dirs.each do |name, path|
    desc "Generate documentation for the #{name} leaf"
    YARD::Rake::YardocTask.new(name.snakecase.to_sym) do |doc|
      output_dir = path.join('..', '..', 'doc', 'leaves', name.snakecase)
      FileUtils.mkdir_p output_dir unless output_dir.directory?

      doc.options << '-m' << 'markdown' << '-M' << 'redcarpet'
      doc.options << '--protected' << '--no-private'
      doc.options << '-r' << path.join('README.md').to_s
      doc.options << '-o' << output_dir.realpath.to_s
      doc.options << '--title' << "#{name} Documentation"

      doc.files = [
          path.join('controller.rb'),
          path.join('helpers', '**', '*.rb'),
          path.join('models', '**', '*.rb'),
          path.join('README.md')
      ].map(&:to_s)
    end
  end

  desc "Generate documentation for all leaves"
  task leaves: leaf_names_and_dirs.map { |(name, _)| name.snakecase.to_sym }

  desc "Generate all documentation"
  task all: [:api, :leaves]

  desc "Remove all documentation"
  task :clear do
    api_doc    = Pathname.new('doc').join('api')
    leaves_doc = Pathname.new('doc').join('leaves')
    FileUtils.remove_dir api_doc if api_doc.directory?
    FileUtils.remove_dir leaves_doc if leaves_doc.directory?
  end
end

# Load any custom Rake tasks in the bot's tasks directory.
Pathname.new('leaves').glob('*').each do |leaf|
  leaf_name = leaf.basename('.rb').to_s.downcase
  namespace leaf_name.to_sym do # Tasks are placed in a namespace named after the leaf
    Pathname.glob(leaf.join('tasks', '**', '*.rake')).sort.each do |task|
      load task
    end
  end
end
