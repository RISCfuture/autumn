require 'yaml'
require 'facets/stylize'
require 'libs/misc'
require 'libs/coder'

module Autumn # :nodoc:
  
  # Generates the files for Autumn templates such as leaves and seasons. The
  # contents of these template files are populated by an LeafCoder instance.
  
  class Generator # :nodoc:
    # The names of the required files in a season's directory, and example
    # for each file.
    SEASON_FILES = {
      "leaves.yml" => {
        'Scorekeeper' => {
          'class' => 'Scorekeeper'
        }
      },
      "stems.yml" => {
        'Example' => {
          'server' => 'irc.yourircserver.com',
          'nick' => 'Yournick',
          'channel' => '#yourchannel',
          'rejoin' => true,
          'leaves' => [ 'Scorekeeper' ]
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
      @coder = TemplateCoder.new
    end
    
    # Generates the files for a new leaf with the given name. Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories created by this method will be added to the project's
    #         VCS. Valid values are <tt>:cvs</tt> and <tt>:svn</tt>.
    
    def leaf(name, options={})
      fname = "leaves/#{name.pathize}.rb"
      if File.exist? fname then
        exists fname, options
      else
        @coder.leaf(name)
        File.open(fname, 'w') { |file| file.puts @coder.output }
        created fname, options
      end
      sname = "support/#{name.pathize}.rb"
      unless File.exist? sname
        spath = "support/#{name.pathize}"
        if File.directory? spath then
          raise "The directory #{spath} already exists."
        elsif File.exist? spath then
          raise "There is a file named #{spath} in the way."
        else
          Dir.mkdir spath
          created spath, options
        end
      end
    end
    
    # Removes the files for a new leaf with the given name. Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories removed by this method will be removed from the
    #         project's VCS. Valid values are <tt>:cvs</tt> and <tt>:svn</tt>.
    
    def unleaf(name, options={})
      fname = "leaves/#{name.pathize}.rb"
      if not File.exist? fname then
        raise "The file #{fname} does not exist."
      else
        FileUtils.rm fname
        deleted fname, options
        sname = "support/#{name.pathize}.rb"
        if File.exist? sname then
          FileUtils.rm sname
          deleted sname, options
        else
          notfound sname, options
        end
        dname = "support/#{name.pathize}"
        if File.directory? dname then
          Dir.glob("#{dname}/*.rb").each do |file|
            FileUtils.rm file
            deleted file, options
          end
          begin
            Dir.rmdir dname
            deleted dname, options
          rescue SystemCallError
            notempty dname, options
          end
        end
      end
    end
    
    # Generates the files and directories for a new season with the given name.
    # Options:
    #
    # +verbose+:: Print to standard output every action that is taken.
    # +vcs+:: The version control system used by this project. The files and
    #         directories created by this method will be added to the project's
    #         VCS. Valid values are <tt>:cvs</tt> and <tt>:svn</tt>.
    
    def season(name, options={})
      dname = "config/seasons/#{name.pathize}"
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
    #         project's VCS. Valid values are <tt>:cvs</tt> and <tt>:svn</tt>.
    
    def unseason(name, options={})
      dname = "config/seasons/#{name.pathize}"
      SEASON_FILES.each do |fname, content|
        fpath = File.join(dname, fname)
        if File.exist? fpath then
          FileUtils.rm fpath
          deleted fpath, options
        else
          notfound fpath, options
        end
      end
      Dir.rmdir dname
      deleted dname, options
    end
    
    private
    
    def created(path, options)
      puts "-- created #{path}" if options[:verbose]
      system "cvs add #{path}" if options[:vcs] == :cvs
      system "svn add #{path}" if options[:vcs] == :svn
    end
    
    def exists(path, options)
      puts "-- exists #{path}" if options[:verbose]
      system "cvs add #{path}" if options[:vcs] == :cvs
      system "svn add #{path}" if options[:vcs] == :svn
    end
    
    def deleted(path, options)
      puts "-- deleted #{path}" if options[:verbose]
      system "cvs remove #{path}" if options[:vcs] == :cvs
      system "svn del --force #{path}" if options[:vcs] == :svn
    end
    
    def notempty(path, options)
      puts "-- notempty #{path}" if options[:verbose]
    end
    
    def notfound(path, options)
      puts "-- notfound #{path}" if options[:verbose]
    end
  end
end
