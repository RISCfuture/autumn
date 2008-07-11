# Controller for the Administrator leaf.

class Controller < Autumn::Leaf
  
  # Typing this command reloads all source code for all leaves and support
  # files, allowing you to make "on-the-fly" changes without restarting the
  # process. It does this by reloading the source files defining the classes.
  #
  # This command does not reload the YAML configuration files, only the source
  # code.
  
  def reload_command(stem, sender, reply_to, msg)
    reload
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
  end
  
  # Suppress the !commands command; don't want to publicize the administrative
  # features.
  
  def commands_command(stem, sender, reply_to, msg)
  end
end
