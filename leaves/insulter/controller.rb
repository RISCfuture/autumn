require 'facets/random'

# Controller and model for the Insulter leaf; maintains the list of insult
# substrings and chooses from them randomly.

class Controller < Autumn::Leaf
  before_filter :authenticate, :only => [ :reload, :quit ]
  
  # Insults the unfortunate argument of this command.
  
  def insult_command(stem, sender, reply_to, msg)
    if msg.nil? then render :help
    else insult msg.capitalize end
  end
  
  # Displays information about the leaf.
  
  def about_command(stem, sender, reply_to, msg)
  end
  
  private
  
  ADJECTIVES = [
    'an artless', 'a bawdy', 'a beslubbering', 'a bootless', 'a churlish',
    'a clouted', 'a cockered', 'a craven', 'a currish', 'a dankish',
    'a dissembling', 'a droning', 'an errant', 'a fawning', 'a fobbing',
    'a frothy', 'a froward', 'a gleeking', 'a goatish', 'a gorbellied',
    'an impertinent', 'an infectious', 'a jarring', 'a loggerheaded',
    'a lumpish', 'a mammering', 'a mangled', 'a mewling', 'a paunchy',
    'a pribbling', 'a puking', 'a puny', 'a qualling', 'a rank', 'a reeky',
    'a roguish', 'a ruttish', 'a saucy', 'a spleeny', 'a spongy', 'a surly',
    'a tottering', 'an unmuzzled', 'a vain', 'a venomed', 'a villainous',
    'a warped', 'a wayward', 'a weedy', 'a yeasty'
  ]
  
  PARTICIPLES = [
    'base-court', 'bat-fowling', 'beef-witted', 'beetle-headed', 'boil-brained',
    'clapper-clawed', 'clay-brained', 'common-kissing', 'crook-pated',
    'dismal-dreaming', 'dizzy-eyed', 'doghearted', 'dread-bolted',
    'earth-vexing', 'elf-skinned', 'fat-kidneyed', 'fen-sucked', 'flap-mouthed',
    'fly-bitten', 'folly-fallen', 'fool-born', 'full-gorged', 'guts-griping',
    'half-faced', 'hasty-witted', 'hedge-born', 'hell-hated', 'idle-headed',
    'ill-breeding', 'ill-nurtured', 'knotty-pated', 'milk-livered',
    'motley-minded', 'onion-eyed', 'plume-plucked', 'pottle-deep', 'pox-marked',
    'reeling-ripe', 'rough-hewn', 'rude-growing', 'rump-fed', 'shard-borne',
    'sheep-biting', 'spur-galled', 'swag-bellied', 'tardy-gaited',
    'tickle-brained', 'toad-spotted', 'urchin-snouted', 'weather-bitten'
  ]
  
  NOUNS = [
    'apple-john', 'baggage', 'barnacle', 'bladder', 'boar-pig', 'bugbear',
    'bum-bailey', 'canker-blossom', 'clack-dish', 'clotpole', 'codpiece',
    'coxcomb', 'death-token', 'dewberry', 'flap-dragon', 'flax-wench',
    'flirt-gill', 'foot-licker', 'fustilarian', 'giglet', 'gudgeon', 'haggard',
    'harpy', 'hedge-pig', 'horn-beast', 'hugger-mugger', 'joithead', 'lewdster',
    'lout', 'maggot-pie', 'malt-worm', 'mammet', 'measle', 'minnow',
    'miscreant', 'moldwarp', 'mumble-news', 'nut-hook', 'pigeon-egg', 'pignut',
    'pumpion', 'puttock', 'ratsbane', 'scut', 'skainsmate', 'strumpet',
    'varlet', 'vassal', 'wagtail', 'whey-face'
  ]
  
  def authenticate_filter(stem, channel, sender, command, msg, opts)
    # Returns true if the sender has any of the privileges listed below
    not ([ :operator, :admin, :founder, :channel_owner ] & [ stem.privilege(channel, sender) ].flatten).empty?
  end
  
  def insult(victim)
    var :adjective => ADJECTIVES.at_rand
    var :participle => PARTICIPLES.at_rand
    var :noun => NOUNS.at_rand
    var :victim => victim
  end
end
