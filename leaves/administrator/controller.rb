# Controller for the Administrator leaf.

class Controller < Autumn::Leaf
  
  # Typing this command reloads all source code for all leaves and support
  # files, allowing you to make "on-the-fly" changes without restarting the
  # process. It does this by reloading the source files defining the classes.
  #
  # If you supply the configuration name of a leaf, only that leaf is reloaded.
  #
  # This command does not reload the YAML configuration files, only the source
  # code.
  
  def reload_command(stem, sender, reply_to, msg)
    var :leaves => Hash.new
    if msg then
      if Foliater.instance.leaves.include?(msg) then
        begin
          Foliater.instance.hot_reload Foliater.instance.leaves[msg]
        rescue
          logger.error "Error when reloading #{msg}:"
          logger.error $!
          var(:leaves)[msg] = $!.to_s
        else
          var(:leaves)[msg] = false
        end
        logger.info "#{msg}: Reloaded"
      else
        var :not_found => msg
      end
    else
      Foliater.instance.leaves.each do |name, leaf|
        begin
          Foliater.instance.hot_reload leaf
        rescue
          logger.error "Error when reloading #{name}:"
          logger.error $!
          var(:leaves)[name] = $!.to_s
        else
          var(:leaves)[name] = false
        end
        logger.info "#{name}: Reloaded"
      end
    end
  end
  ann :reload_command, :protected => true
  
  # Typing this command will cause the Stem to exit.
  
  def quit_command(stem, sender, reply_to, msg)
    stem.quit
  end
  ann :quit_command, :protected => true
  
  # Typing this command will display information about the version of Autumn
  # that is running this leaf.
  
  def autumn_command(stem, sender, reply_to, msg)
    var :version => AUTUMN_VERSION
  end
  
  # Suppress the !commands command; don't want to publicize the administrative
  # features.
  
  def commands_command(stem, sender, reply_to, msg)
  end
end
