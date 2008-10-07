require 'set'
require 'rubygems'
require 'facets/array'
require 'facets/string'

require 'libs/misc'
require 'libs/daemon'

describe Autumn::Daemon do
  it "should not allow the creation of a default Daemon" do
    lambda { Autumn::Daemon.new nil, nil }.should raise_error
  end
  
  describe "(the default daemon)" do
    it "should exist" do
      Autumn::Daemon.default.should_not be_nil
    end
    
    it "should parrot unknown properties" do
      Autumn::Daemon.default.usermode['~'].should eql('~')
      Autumn::Daemon.default.privilege['~'].should eql('~')
      Autumn::Daemon.default.user_prefix['('].should eql('(')
      Autumn::Daemon.default.channel_prefix['('].should eql('(')
      Autumn::Daemon.default.channel_mode['~'].should eql('~')
      Autumn::Daemon.default.server_mode['~'].should eql('~')
      Autumn::Daemon.default.event[123].should eql(123)
    end
  end
  
  describe "with some standard options" do
    before :each do
      @daemon = Autumn::Daemon.new 'daemon', {
        'usermode' => { 'f' => :first_usermode, 's' => :second_usermode },
        'privilege' => { 'f' => :first_priv, 's' => :second_priv },
        'user_prefix' => { '+' => :first_priv, '-' => :second_priv },
        'channel_prefix' => { '#' => :first_chantype, '&' => :second_chantype },
        'channel_mode' => { 'c' => :first_chanmode, 'd' => :second_chanmode },
        'server_mode' => { 'F' => :first_srvrmode, 'S' => :second_srvrmode },
        'event' => { 998 => :first_event, 997 => :second_event }
      }
    end
  
    it "should associate a Daemon with its name" do
      Autumn::Daemon['daemon'].should equal(@daemon)
    end
    
    it "should update the default Daemon with its properties" do
      Autumn::Daemon.default.usermode['f'].should eql(:first_usermode)
      Autumn::Daemon.default.privilege['f'].should eql(:first_priv)
      Autumn::Daemon.default.user_prefix['+'].should eql(:first_priv)
      Autumn::Daemon.default.channel_prefix['#'].should eql(:first_chantype)
      Autumn::Daemon.default.channel_mode['c'].should eql(:first_chanmode)
      Autumn::Daemon.default.server_mode['F'].should eql(:first_srvrmode)
      Autumn::Daemon.default.event[998].should eql(:first_event)
    end
    
    it "should return hashes merged with the default" do
      Autumn::Daemon.default.usermode['b'] = :new_usermode
      Autumn::Daemon.default.privilege['b'] = :new_priv
      Autumn::Daemon.default.user_prefix['$'] = :new_uprefix
      Autumn::Daemon.default.channel_prefix['%'] = :new_cprefix
      Autumn::Daemon.default.channel_mode['b'] = :new_chanmode
      Autumn::Daemon.default.server_mode['B'] = :new_srvmode
      Autumn::Daemon.default.event[100] = :new_event
      
      @daemon.usermode['b'].should eql(:new_usermode)
      @daemon.privilege['b'].should eql(:new_priv)
      @daemon.user_prefix['$'].should eql(:new_uprefix)
      @daemon.channel_prefix['%'].should eql(:new_cprefix)
      @daemon.channel_mode['b'].should eql(:new_chanmode)
      @daemon.server_mode['B'].should eql(:new_srvmode)
      @daemon.event[100].should eql(:new_event)
    end
    
    it "should parrot unknown properties" do
      @daemon.usermode['~'].should eql('~')
      @daemon.privilege['~'].should eql('~')
      @daemon.user_prefix['('].should eql('(')
      @daemon.channel_prefix['('].should eql('(')
      @daemon.channel_mode['~'].should eql('~')
      @daemon.server_mode['~'].should eql('~')
      @daemon.event[123].should eql(123)
    end
    
    it "should recognize a change in user privilege as such" do
      @daemon.privilege_mode?('+f').should be_true
    end
    
    it "should recognize a change in channel mode as such" do
      @daemon.privilege_mode?('+c').should be_false
    end
    
    it "should raise an exception when privilege_mode? is called with an invalid mode string" do
      lambda { @daemon.privilege_mode?('invalid') }.should raise_error
    end
    
    it "should recognize when a nick is prefixed" do
      @daemon.nick_prefixed?('+Nick').should be_true
    end
    
    it "should recognize when a nick is not prefixed" do
      @daemon.nick_prefixed?('Nick').should be_false
    end
    
    it "should be able to strip a nick of prefix characters" do
      @daemon.just_nick('+Nick').should eql('Nick')
    end
    
    it "should, when asked to strip a nick with no prefix characters, return that same nick" do
      @daemon.just_nick('Nick').should eql('Nick')
    end
    
    it "should give the privilege of a nick with no prefixes as :unvoiced" do
      @daemon.nick_privilege('Nick').should eql(:unvoiced)
    end
    
    it "should correctly give the privilege of a nick with one prefix" do
      @daemon.nick_privilege('+Nick').should eql(:first_priv)
    end
    
    it "should correctly give the privileges of a nick with multiple prefixes" do
      @daemon.nick_privilege('+-Nick').should == [ :first_priv, :second_priv ].to_set
    end
    
    it "should add predicate methods for each hash which return true for known values" do
      @daemon.usermode?('f').should be_true
      @daemon.privilege?('f').should be_true
      @daemon.user_prefix?('+').should be_true
      @daemon.channel_prefix?('#').should be_true
      @daemon.channel_mode?('c').should be_true
      @daemon.server_mode?('F').should be_true
      @daemon.event?(998).should be_true
    end
    
    it "... and return false for unknown values" do
      @daemon.usermode?('~').should be_false
      @daemon.privilege?('~').should be_false
      @daemon.user_prefix?('(').should be_false
      @daemon.channel_prefix?('(').should be_false
      @daemon.channel_mode?('~').should be_false
      @daemon.server_mode?('~').should be_false
      @daemon.event?(123).should be_false
    end
    
    it "... and should work with numeric prefix characters" do
      @daemon.user_prefix?(?+).should be_true
      @daemon.channel_prefix?(?#).should be_true
    end
    
    it "... and should return values in the default daemon as well" do
      Autumn::Daemon.default.usermode['b'] = :new_usermode
      Autumn::Daemon.default.privilege['b'] = :new_priv
      Autumn::Daemon.default.user_prefix['$'] = :new_uprefix
      Autumn::Daemon.default.channel_prefix['%'] = :new_cprefix
      Autumn::Daemon.default.channel_mode['b'] = :new_chanmode
      Autumn::Daemon.default.server_mode['B'] = :new_srvmode
      Autumn::Daemon.default.event[100] = :new_event
      
      @daemon.usermode?('b').should be_true
      @daemon.privilege?('b').should be_true
      @daemon.user_prefix?('$').should be_true
      @daemon.channel_prefix?('%').should be_true
      @daemon.channel_mode?('b').should be_true
      @daemon.server_mode?('B').should be_true
      @daemon.event?(100).should be_true
    end
    
    describe "initialized along with a second Daemon with some duplicate properties" do
      before :each do
        @daemon2 = Autumn::Daemon.new 'daemon2', {
          'usermode' => { 'f' => :first_usermode, 's' => :other_usermode },
          'privilege' => { 'f' => :first_priv, 's' => :other_priv },
          'user_prefix' => { '+' => :first_priv, '-' => :other_priv },
          'channel_prefix' => { '#' => :first_chantype, '&' => :other_chantype },
          'channel_mode' => { 'c' => :first_chanmode, 'd' => :other_chanmode },
          'server_mode' => { 'F' => :first_srvrmode, 'S' => :other_srvrmode },
          'event' => { 998 => :first_event, 997 => :other_event }
        }
      end
      
      it "should not remove the duplicate properties with identical values from the default Daemon" do
        Autumn::Daemon.default.usermode['f'].should eql(:first_usermode)
        Autumn::Daemon.default.privilege['f'].should eql(:first_priv)
        Autumn::Daemon.default.user_prefix['+'].should eql(:first_priv)
        Autumn::Daemon.default.channel_prefix['#'].should eql(:first_chantype)
        Autumn::Daemon.default.channel_mode['c'].should eql(:first_chanmode)
        Autumn::Daemon.default.server_mode['F'].should eql(:first_srvrmode)
        Autumn::Daemon.default.event[998].should eql(:first_event)
      end
      
      it "should remove the duplicate properties with different values from the default Daemon" do
        Autumn::Daemon.default.usermode['s'].should eql('s')
        Autumn::Daemon.default.privilege['s'].should eql('s')
        Autumn::Daemon.default.user_prefix['-'].should eql('-')
        Autumn::Daemon.default.channel_prefix['&'].should eql('&')
        Autumn::Daemon.default.channel_mode['d'].should eql('d')
        Autumn::Daemon.default.server_mode['S'].should eql('S')
        Autumn::Daemon.default.event[997].should eql(997)
      end
    end
  end
end
