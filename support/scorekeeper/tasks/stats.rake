desc "Display the current scores of every channel"
task :scores => :full_bootstrap do
  Channel.all do |channel|
    scores = Score.all(:channel_id.eql => channel.id)
    scores.inject(Hash.new(0)) { |hsh, score| hsh[score.receiver.name] += score.change; hsh }
    print_scores = scores.sort { |a,b| b.last <=> a.last }.collect { |n,p| "#{n}: #{p}" }.join(', ')
    puts "#{channel.server}:#{channel.name} -- #{print_scores}"
  end
end
