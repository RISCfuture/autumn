# Defines the Autumn::Generator class, which generates and destroys files and
# directories of Autumn objects for script/generate.

require 'yaml'
require 'libs/coder'

module Autumn
  
  # Generates the files for Autumn templates such as leaves and seasons. The
  # contents of these template files are populated by an LeafCoder instance.
  
  class Generator # :nodoc:
    # The names of the required files in a season's directory, and example
    # for each file.
    SEASON_FILES = {
      "leaves.yml" => {
        'Scorekeeper' => {
          'class' => 'Scorekeeper'
        },
        'Insulter' => {
          'class' => 'Insulter'
        },
        'Administrator' => {
          'class' => 'Administrator',
          'authentication' => {
            'type' => 'op'
          }
        }
      },
      "stems.yml" => {
        'Example' => {
          'server' => 'irc.yourircserver.com',
          'nick' => 'MyIRCBot',
          'channel' => '#yourchannel',
          'rejoin' => true,
          'leaves' => [ 'Administrator', 'Scorekeeper', 'Insulter' ]
        }
      },
      "season.yml" => {
        'logging' => 'debug'
      },
      'database.yml' => {
        'Example' => {
          'adapter' => 'mysql',
          'host' => 'localhost',
          'username' => 'root',
          'password' => '',
          'database' => 'example_database'
        }
      }
    }
    
    # Creates a new instance.
    
    def initialize
      @coder = Autumn::TemplateCoder.new
    end
    
    # Generates the files for a new leaf with the given name. Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories created by this method will be added to the project's
    #         VCS.
    
    def leaf(name, options={})
      lpath = "leaves/#{name.snakecase}"
      if File.directory? lpath then
        exists lpath, options
        return
      elsif File.exist? lpath then
        raise "There is a file named #{lpath} in the way."
      else
        Dir.mkdir lpath
        created lpath, options
      end
      
      cname = "leaves/#{name.snakecase}/controller.rb"
      if File.exist? cname then
        exists cname, options
      else
        @coder.leaf(name)
        File.open(cname, 'w') { |file| file.puts @coder.output }
        created cname, options
      end
      
      dpath = "leaves/#{name.snakecase}/data"
      if File.directory? dpath then
        exists dpath, options
      else
        Dir.mkdir dpath
        created dpath, options
      end
      
      [ 'lib', 'helpers', 'models', 'tasks', 'views' ].each do |dir|
        path = "leaves/#{name.snakecase}/#{dir}"
        if File.directory? path then
          exists path, options
        elsif File.exist? path then
          raise "There is a file named #{path} in the way."
        else
          Dir.mkdir path
          created path, options
        end
      end
      
      vname = "leaves/#{name.snakecase}/views/about.txt.erb"
      if File.exist? vname then
        exists cname, options
      else
        File.open(vname, 'w') { |file| file.puts "Insert your about string here!" }
        created vname, options
      end
      
      rname = "leaves/#{name.snakecase}/README"
      if File.exist? rname then
        exists rname, options
      else
        File.open(rname, 'w') { |file| file.puts "This is the read-me for your leaf." }
        created rname, options
      end
    end
    
    # Removes the files for a new leaf with the given name. Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories removed by this method will be removed from the
    #         project's VCS.
    
    def unleaf(name, options={})
      lpath = "leaves/#{name.snakecase}"
      if not File.directory? lpath then
        raise "The directory #{lpath} doesn't exist."
      end
      
      if File.directory? "#{lpath}/data" and Dir.entries("#{lpath}/data").size > 2 then
        print "\a" # ring the bell
        puts "WARNING: Files exist in this leaf's data directory!"
        puts "Type Ctrl-C in the next ten seconds if you don't want these files to be deleted..."
        (0..9).each do |num|
          print "#{10 - num}... "
          $stdout.flush
          sleep 1
        end
        print "\n"
      end
      
      FileUtils.remove_dir lpath
      deleted lpath, options
    end
    
    # Generates the files and directories for a new season with the given name.
    # Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories created by this method will be added to the project's
    #         VCS.
    
    def season(name, options={})
      dname = "config/seasons/#{name.snakecase}"
      if File.directory? dname then
        raise "The directory #{dname} already exists."
      elsif File.exist? dname then
        raise "There is a file named #{dname} in the way."
      else
        Dir.mkdir dname
        created dname, options
        SEASON_FILES.each do |fname, content|
          fpath = File.join(dname, fname)
          if File.exist? fpath then
            exists fpath, options
          else
            File.open(fpath, 'w') { |file| file.puts content.to_yaml }
            created fpath, options
          end
        end
      end
    end
    
    # Removes the files and directories for a season with the given name.
    # Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories removed by this method will be removed from the
    #         project's VCS.
    
    def unseason(name, options={})
      dname = "config/seasons/#{name.snakecase}"
      if not File.directory? dname then
        raise "The directory #{dname} doesn't exist."
      end
      
      FileUtils.remove_dir dname
      deleted dname, options
    end
    
    private
    
    def created(path, options)
      puts "-- created #{path}" if options[:verbose]
      system "cvs add #{path}" if options[:vcs] == :cvs
      system "svn add #{path}" if options[:vcs] == :svn
      system "git add #{path}" if options[:vcs] == :git
    end
    
    def exists(path, options)
      puts "-- exists #{path}" if options[:verbose]
      system "cvs add #{path}" if options[:vcs] == :cvs
      system "svn add #{path}" if options[:vcs] == :svn
      system "git add #{path}" if options[:vcs] == :git
    end
    
    def deleted(path, options)
      puts "-- deleted #{path}" if options[:verbose]
      system "cvs remove #{path}" if options[:vcs] == :cvs
      system "svn del --force #{path}" if options[:vcs] == :svn
      system "git rm -r #{path}" if options[:vcs] == :git
    end
    
    def notempty(path, options)
      puts "-- notempty #{path}" if options[:verbose]
    end
    
    def notfound(path, options)
      puts "-- notfound #{path}" if options[:verbose]
    end
  end
end
