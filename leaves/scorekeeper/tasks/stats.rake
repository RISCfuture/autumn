desc "Display the current scores of every channel"
task :scores => :boot do
  Autumn::Foliater.instance.leaves.select { |name, leaf| leaf.kind_of? Scorekeeper::Controller }.each do |name, leaf|
    puts "Leaf #{name}"
    leaf.database do
      Scorekeeper::Channel.all.group_by { |chan| chan.server }.each do |server, channels|
        puts "  #{server}"
        channels.each do |channel|
          scores = channel.scores
          vals = scores.inject(Hash.new(0)) { |hsh, score| hsh[score.receiver.name] += score.change; hsh }
          print_scores = vals.sort { |a,b| b.last <=> a.last }.collect { |n,p| "#{n}: #{p}" }.join(', ')
          puts "    #{channel.name} - #{print_scores}"
        end
      end
    end
  end
end
