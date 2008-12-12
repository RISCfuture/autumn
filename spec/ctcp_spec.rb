require 'set'
require 'rubygems'
require 'facets/array'
require 'facets/enumerable'
require 'facets/kernel'
require 'facets/string'
require 'anise'

require 'libs/misc'
require 'libs/stem_facade'
require 'libs/daemon'
require 'libs/stem'
require 'libs/ctcp'

describe Autumn::CTCP do
  before :each do
    @ctcp = Autumn::CTCP.new
    @sender_hash = { :user => 'TestUser', :nick => 'TestNick', :host => 'ca.testhost.org' }
  end
  
  describe "with a mock stem" do
    before :each do
      @stem = mock('stem')
    end
    
    it "should parse CTCP requests in PRIVMSGs and broadcast two request-received methods" do
      @stem.should_receive(:broadcast).once.with(:ctcp_test_request, @ctcp, @stem, @sender_hash, [])
      @stem.should_receive(:broadcast).once.with(:ctcp_request_received, :test, @ctcp, @stem, @sender_hash, [])
      @ctcp.irc_privmsg_event @stem, @sender_hash, :message => "\01TEST\01"
    end

    it "should parse unencoded arguments in CTCP requests" do
      @stem.should_receive(:broadcast).once.with(:ctcp_test_request, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg2' ])
      @stem.should_receive(:broadcast).once.with(:ctcp_request_received, :test, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg2' ])
      @ctcp.irc_privmsg_event @stem, @sender_hash, :message => "\01TEST arg1 arg2\01"
    end
    
    it "should parse encoded arguments in CTCP requests" do
      Autumn::CTCP::ENCODED_COMMANDS << 'TEST'
      @stem.should_receive(:broadcast).once.with(:ctcp_test_request, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg 2' ])
      @stem.should_receive(:broadcast).once.with(:ctcp_request_received, :test, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg 2' ])
      @ctcp.irc_privmsg_event @stem, @sender_hash, :message => "\01TEST arg1 arg\\@2\01"
    end
    
    it "should correctly unescape all magic characters in its response" do
      Autumn::CTCP::ENCODED_COMMANDS << 'TEST'
      @stem.should_receive(:broadcast).once.with(:ctcp_test_request, @ctcp, @stem, @sender_hash, [ "\000\001\n\r \\" ])
      @stem.should_receive(:broadcast).once.with(:ctcp_request_received, :test, @ctcp, @stem, @sender_hash, [ "\000\001\n\r \\" ])
      @ctcp.irc_privmsg_event @stem, @sender_hash, :message => "\01TEST \\0\\1\\n\\r\\@\\\\\01"
    end

    it "should not parse space escapes in unencoded arguments in CTCP requests" do
      @stem.should_receive(:broadcast).once.with(:ctcp_test_request, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg\@2' ])
      @stem.should_receive(:broadcast).once.with(:ctcp_request_received, :test, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg\@2' ])
      @ctcp.irc_privmsg_event @stem, @sender_hash, :message => "\01TEST arg1 arg\\@2\01"
    end

    it "should parse CTCP responses in NOTICEs and broadcast two response-received methods" do
      @stem.should_receive(:broadcast).once.with(:ctcp_test_response, @ctcp, @stem, @sender_hash, [])
      @stem.should_receive(:broadcast).once.with(:ctcp_response_received, :test, @ctcp, @stem, @sender_hash, [])
      @ctcp.irc_notice_event @stem, @sender_hash, :message => "\01TEST\01"
    end

    it "should parse unencoded arguments in CTCP responses" do
      @stem.should_receive(:broadcast).once.with(:ctcp_test_response, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg2' ])
      @stem.should_receive(:broadcast).once.with(:ctcp_response_received, :test, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg2' ])
      @ctcp.irc_notice_event @stem, @sender_hash, :message => "\01TEST arg1 arg2\01"
    end

    it "should parse encoded arguments in CTCP responses" do
      Autumn::CTCP::ENCODED_COMMANDS << 'TEST'
      @stem.should_receive(:broadcast).once.with(:ctcp_test_response, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg 2' ])
      @stem.should_receive(:broadcast).once.with(:ctcp_response_received, :test, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg 2' ])
      @ctcp.irc_notice_event @stem, @sender_hash, :message => "\01TEST arg1 arg\\@2\01"
    end

    it "should not parse space escapes in unencoded arguments in CTCP responses" do
      @stem.should_receive(:broadcast).once.with(:ctcp_test_response, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg\@2' ])
      @stem.should_receive(:broadcast).once.with(:ctcp_response_received, :test, @ctcp, @stem, @sender_hash, [ 'arg1', 'arg\@2' ])
      @ctcp.irc_notice_event @stem, @sender_hash, :message => "\01TEST arg1 arg\\@2\01"
    end
  end
  
  describe "with an actual stem" do
    before :each do
      @ctcp.instance_variable_set(:@reply_queue, Hash.new { |h,k| h[k] = Array.new })
      
      @stem = Autumn::Stem.new('irc.example.com', 'Example', :channel => '#example')
      #TODO proper way to stub this?
      @stem.instance_eval do
        def privmsg(*args)
          args
        end
      end
      @stem.add_listener @ctcp
    end
    
    it "should set the @ctcp variable in a stem when it's added as a listener to that stem" do
      @stem.instance_variable_get(:@ctcp).should eql(@ctcp)
    end
    
    it "should add a method of the form ctcp_* to the stem" do
      lambda { @stem.ctcp_action("#example") }.should_not raise_error(NoMethodError)
    end
    
    it "... which replies with a CTCP message" do
      @stem.ctcp_action("#example").should eql([ "#example", "\001ACTION\001" ])
    end
    
    it "... ... that properly encodes arguments when appropriate" do
      @stem.ctcp_ping("#example", 'arg1', 'arg 2').should eql([ "#example", "\001PING arg1 arg\\@2\001" ])
    end
    
    it "... ... ... escaping all magic characters" do
      @stem.ctcp_ping("#example", "\n\r \\\000\001").should eql([ "#example", "\001PING " + '\n\r\@\\\\\0\1' + "\001" ])
    end
    
    it "... ... that does not encode arguments when appropriate" do
      @stem.ctcp_action("#example", "ABC 123").should eql([ "#example", "\001ACTION ABC 123\001" ])
    end
    
    it "should add a method of the form ctcp_reply_* to the stem" do
      lambda { @stem.ctcp_reply_ping("Pinger") }.should_not raise_error(NoMethodError)
    end
    
    it "... which replies with a CTCP response" do
      @stem.ctcp_reply_ping("Pinger")
      reply_queue(@ctcp, @stem).shift.should == { :recipient => "Pinger", :message => "\001PING\001" }
    end
        
    it "... ... that properly encodes arguments when appropriate" do
      @stem.ctcp_reply_ping("Pinger", 'arg1', 'arg 2')
      reply_queue(@ctcp, @stem).shift.should == { :recipient => "Pinger", :message => "\001PING arg1 arg\\@2\001" }
    end
    
    it "... ... ... escaping all magic characters" do
      @stem.ctcp_reply_ping("Pinger", "\n\r \\\000\001")
      reply_queue(@ctcp, @stem).shift.should == { :recipient => "Pinger", :message => "\001PING " + '\n\r\@\\\\\0\1' + "\001" }
    end
    
    it "... ... that does not encode arguments when appropriate" do
      @stem.ctcp_reply_example("Tester", "ABC 123")
      reply_queue(@ctcp, @stem).shift.should == { :recipient => "Tester", :message => "\001EXAMPLE ABC 123\001" }
    end
  end
  
  describe "with a mock stem that records message intervals" do
    before :each do
      @stem = Object.new
      class << @stem
        attr :received
        
        def notice(*args)
          @received ||= Array.new
          @received << Time.now
        end
        
        def privmsg(*args)
        end
        
        def average_interval
          times = Array.new
          @received.each_by { |a, b| times << b - a if a and b }
          return times.sum/times.size.to_f
        end
      end
      
      @ctcp.added @stem
    end
    
    it "should queue replies and fire them at the default interval of 0.25 seconds" do
      10.times { @stem.ctcp_reply_ping "Pinger", "ABC123" }
      sleep 3
      @stem.average_interval.should be_close(0.25, 0.05)
    end
    
    it "should drop replies from the queue when the default maximum of 10 is exceeded" do
      Thread.exclusive { 15.times { @stem.ctcp_reply_ping "Pinger", "ABC123" } }
      sleep 4
      @stem.received.size.should be_close(10, 1.5)
    end
    
    describe "with custom CTCP reply rate and queue length values" do
      before :each do
        @ctcp = Autumn::CTCP.new(:reply_rate => 0.5, :reply_queue_size => 5)
        @ctcp.added @stem
      end
      
      it "should queue replies and fire them at a custom interval" do
        5.times { @stem.ctcp_reply_ping "Pinger", "ABC123" }
        sleep 3
        @stem.average_interval.should be_close(0.5, 0.05)
      end
      
      it "should drop replies from the queue when a custom maximum is exceeded" do
        15.times { @stem.ctcp_reply_ping "Pinger", "ABC123" }
        sleep 4
        @stem.received.size.should be_close(5, 1.5)
      end
    end
  end
  
  it "should respond to CTCP VERSION requests" do
    @ctcp.should respond_to(:ctcp_version_request)
  end
  
  it "should respond to CTCP PING requests" do
    @ctcp.should respond_to(:ctcp_ping_request)
  end
  
  it "should respond to CTCP TIME requests" do
    @ctcp.should respond_to(:ctcp_time_request)
  end
      
  after :each do
    Autumn::CTCP::ENCODED_COMMANDS.delete 'TEST'
  end
  
  def reply_queue(ctcp, stem)
    ctcp.instance_variable_get(:@reply_queue)[stem]
  end
end
