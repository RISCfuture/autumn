require 'yaml'
require 'pathname'
require 'libs/coder'
require 'pathname' 

module Autumn

  # Generates the files for Autumn templates such as leaves and seasons. The
  # contents of these template files are populated by a {Coder} instance.

  class Generator
    # The names of the required files in a season's directory, and example for
    # each file.
    SEASON_FILES = {
        'leaves.yml' => {
            'Scorekeeper'   => {
                'class' => 'Scorekeeper'
            },
            'Insulter'      => {
                'class' => 'Insulter'
            },
            'Administrator' => {
                'class'          => 'Administrator',
                'authentication' => {
                    'type' => 'op'
                }
            }
        },
        'stems.yml' => {
            'Example' => {
                'server'  => 'irc.yourircserver.com',
                'nick'    => 'MyIRCBot',
                'channel' => '#yourchannel',
                'rejoin'  => true,
                'leaves'  => %w(Administrator Scorekeeper Insulter)
            }
        },
        'season.yml' => {
            'logging' => 'debug'
        },
        'database.yml' => {
            'Example' => 'sqlite:path/to/example_database.db'
        }
    }

    # Creates a new instance.

    def initialize
      @coder = Autumn::TemplateCoder.new
    end

    # Generates the files for a new Leaf with the given name.
    #
    # @param [String] name The Leaf name.
    # @param [Hash] options Leaf options.
    # @option options [true, false] :verbose (false) If `true`, prints to
    #   standard output every action that is taken.
    # @option options [:cvs, :svn, :git, nil] :vcs The version control system
    #   used by this project. The files and directories created by this method
    #   will be added to the project's VCS.

    def leaf(name, options={})
      lpath = Pathname.new('leaves').join(name.snakecase)
      if lpath.directory?
        exists lpath, options
        return
      elsif lpath.exist?
        raise "There is a file named #{lpath} in the way."
      else
        Dir.mkdir lpath
        created lpath, options
      end

      cname = lpath.join('controller.rb')
      if cname.exist?
        exists cname, options
      else
        @coder.leaf(name)
        File.open(cname, 'w') { |file| file.puts @coder.output }
        created cname, options
      end

      dpath = lpath.join('data')
      if dpath.directory?
        exists dpath, options
      else
        Dir.mkdir dpath
        created dpath, options
      end

      gname = lpath.join('Gemfile')
      if gname.exist?
        exists gname, options
      else
        File.open(gname, 'w') { |file| file.puts "group :#{name.snakecase} do\n  # Insert your leaf's gem requirements here\nend" }
        created gname, options
      end

      %w(lib helpers models tasks views).each do |dir|
        path = lpath.join('dir')
        if path.directory?
          exists path, options
        elsif path.exist?
          raise "There is a file named #{path} in the way."
        else
          Dir.mkdir path
          created path, options
        end
      end

      dname = lpath.join('views')
      unless File.directory?(dname)
        Dir.mkdir(dname)
        created dname, options
      end
           
      vname = lpath.join('views', 'about.txt.erb')
      if vname.exist?
        exists cname, options
      else
        File.open(vname, 'w') { |file| file.puts "Insert your about string here!" }
        created vname, options
      end

      rname = lpath.join('README')
      if rname.exist?
        exists rname, options
      else
        File.open(rname, 'w') { |file| file.puts "This is the read-me for your leaf." }
        created rname, options
      end
    end

    # Removes the files for a new leaf with the given name.
    #
    # @param [String] name The Leaf name.
    # @param [Hash] options Leaf options.
    # @option options [true, false] :verbose (false) If `true`, prints to
    #   standard output every action that is taken.
    # @option options [:cvs, :svn, :git, nil] :vcs The version control system
    #   used by this project. The files and directories created by this method
    #   will be removed from the project's VCS.


    def unleaf(name, options={})
      lpath = Pathname.new('leaves').join(name.snakecase)

      unless lpath.directory?
        raise "The directory #{lpath} doesn't exist."
      end

      data = lpath.join('data')
      if data.directory? && data.entries.size > 2
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
    # @param [String] name The season name.
    # @param [Hash] options Season options.
    # @option options [true, false] :verbose (false) If `true`, prints to
    #   standard output every action that is taken.
    # @option see #leaf


    def season(name, options={})
      dname = Pathname.new('config').join('seasons', name.snakecase)
      if dname.directory?
        raise "The directory #{dname} already exists."
      elsif dname.exist?
        raise "There is a file named #{dname} in the way."
      else
        Dir.mkdir dname
        created dname, options
        SEASON_FILES.each do |fname, content|
          fpath = dname.join(fname)
          if fpath.exist?
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
    # @param [String] name The season name.
    # @param [Hash] options Season options.
    # @option options [true, false] :verbose (false) If `true`, prints to
    #   standard output every action that is taken.
    # @option see #unleaf

    def unseason(name, options={})
      dname = Pathname.new('config').join('seasons', name.snakecase)
      unless dname.directory?
        raise "The directory #{dname} doesn't exist."
      end

      FileUtils.remove_dir dname
      deleted dname, options
    end

    private

    def created(path, options)
      puts "-- created #{path}" if options[:verbose]
      system 'cvs', 'add', path if options[:vcs] == :cvs
      system 'svn', 'add', path if options[:vcs] == :svn
      system 'git', 'add', path if options[:vcs] == :git
    end

    def exists(path, options)
      puts "-- exists #{path}" if options[:verbose]
      system 'cvs', 'add', path if options[:vcs] == :cvs
      system 'svn', 'add', path if options[:vcs] == :svn
      system 'git', 'add', path if options[:vcs] == :git
    end

    def deleted(path, options)
      puts "-- deleted #{path}" if options[:verbose]
      system 'cvs', 'remove', path if options[:vcs] == :cvs
      system 'svn', 'del', '--force', path if options[:vcs] == :svn
      system 'git', 'rm', '-r', path if options[:vcs] == :git
    end

    def notempty(path, options)
      puts "-- notempty #{path}" if options[:verbose]
    end

    def notfound(path, options)
      puts "-- notfound #{path}" if options[:verbose]
    end
  end
end
