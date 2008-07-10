require 'logger'
require 'set'

require 'libs/genesis'

gen = Autumn::Genesis.new
gen.load_libraries
gen.load_daemon_info

describe Autumn::ChannelLeaf do
  before :all do
    #TODO how do we stub these methods?
    Autumn::Leaf.class_eval do
      def irc_privmsg_event(*args); true; end
      def irc_join_event(*args); true; end
      def irc_part_event(*args); true; end
      def irc_mode_event(*args); true; end
      def irc_topic_event(*args); true; end
      def irc_invite_event(*args); true; end
      def irc_kick_event(*args); true; end
      def irc_notice_event(*args); true; end
    end
  end
  
  before :each do
    @logger = Autumn::LogFacade.new Logger.new(STDOUT), 'Leaf', 'Channel Leaf Spec'
    @stem = Autumn::Stem.new('irc.mockserver.com', 'MockStem', { :channels => [ '#listening', '#notlistening' ]})
    Autumn::Foliater.instance.stems['Mock'] = @stem
    @sender_hash = { :nick => 'nick', :host => 'ca.us.host.com', :user => 'user' }
  end
  
  describe "with a valid stem" do
    before :each do
      @leaf = Autumn::ChannelLeaf.new :logger => @logger, :channels => { 'Mock' => [ '#listening' ] }
    end
    
    it "should not raise an exception on startup" do
      lambda { @leaf.will_start_up }.should_not raise_error(RuntimeError, "Unknown stem MockStem")
    end
    
    describe "that has started up" do
      before :each do
        @leaf.will_start_up
      end
      
      it "should notice PRIVMSGs on channels it is listening to" do
        @leaf.irc_privmsg_event(@stem, @sender_hash, { :channel => '#listening', :message => 'message' }).should equal(true)
      end

      it "should not notice PRIVMSGs on channels it is not listening to" do
        @leaf.irc_privmsg_event(@stem, @sender_hash, { :channel => '#notlistening', :message => 'message' }).should_not equal(true)
      end

      it "should notice PRIVMSGs to itself" do
        @leaf.irc_privmsg_event(@stem, @sender_hash, { :recipient => 'MockStem', :message => 'message' }).should equal(true)
      end

      it "should notice JOINs on channels it is listening to" do
        @leaf.irc_join_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice JOINs on channels it is not listening to" do
        @leaf.irc_join_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice PARTs on channels it is listening to" do
        @leaf.irc_part_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice PARTs on channels it is not listening to" do
        @leaf.irc_part_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice MODEs on channels it is listening to" do
        @leaf.irc_mode_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice MODEs on channels it is not listening to" do
        @leaf.irc_mode_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice MODE changes to iself" do
        @leaf.irc_mode_event(@stem, @sender_hash, { :recipient => 'MockStem', :message => 'message' }).should equal(true)
      end

      it "should notice TOPICs on channels it is listening to" do
        @leaf.irc_topic_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice TOPICs on channels it is not listening to" do
        @leaf.irc_topic_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice INVITEs on channels it is listening to" do
        @leaf.irc_invite_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice INVITEs on channels it is not listening to" do
        @leaf.irc_invite_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should not notice INVITEs to me to channels I am not listening to" do
        @leaf.irc_invite_event(@stem, @sender_hash, { :recipient => 'MockStem', :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice INVITEs to me to channels I am not a part of" do
        @leaf.irc_invite_event(@stem, @sender_hash, { :recipient => 'MockStem', :channel => '#notamember' }).should equal(true)
      end

      it "should notice KICKs on channels it is listening to" do
        @leaf.irc_kick_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice KICKs on channels it is not listening to" do
        @leaf.irc_notice_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice NOTICEs on channels it is listening to" do
        @leaf.irc_notice_event(@stem, @sender_hash, { :channel => '#listening' }).should equal(true)
      end

      it "should not notice NOTICEs on channels it is not listening to" do
        @leaf.irc_notice_event(@stem, @sender_hash, { :channel => '#notlistening' }).should_not equal(true)
      end

      it "should notice NOTICEs to itself" do
        @leaf.irc_notice_event(@stem, @sender_hash, { :recipient => 'MockStem', :message => 'message' }).should equal(true)
      end
    end
  end
  
  describe "with an invalid stem" do
    before :each do
      @leaf = Autumn::ChannelLeaf.new :logger => @logger, :channels => { 'Nonexistent' => [ '#listening' ] }
    end
    
    it "should raise an exception on startup" do
      lambda { @leaf.will_start_up }.should raise_error(RuntimeError, "Unknown stem Nonexistent")
    end
  end
end
