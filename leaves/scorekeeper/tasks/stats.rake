desc "Display the current scores of every channel"
task :scores => :full_bootstrap do
  Autumn::Foliater.instance.leaves.select { |name, leaf| leaf.kind_of? Scorekeeper }.each do |name, leaf|
    leaf.database do
      Channel.all.each do |channel|
        scores = Score.all(:channel_id.eql => channel.id)
        vals = scores.inject(Hash.new(0)) { |hsh, score| hsh[score.receiver.name] += score.change; hsh }
        print_scores = vals.sort { |a,b| b.last <=> a.last }.collect { |n,p| "#{n}: #{p}" }.join(', ')
        puts "Leaf #{name} - #{channel.server}:#{channel.name} - #{print_scores}"
      end
    end
  end
end
