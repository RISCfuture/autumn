class Controller < Autumn::Leaf
  def about_command(stem, sender, reply_to, msg)
    var :test_val => 'zomg'
  end
end
