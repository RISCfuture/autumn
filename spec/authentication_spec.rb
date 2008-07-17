require 'rubygems'
require 'facets'

require 'libs/authentication'

describe Autumn::Authentication::Base do
  it "should raise an exception when initialized" do
    lambda { Autumn::Authentication::Base.new }.should raise_error
  end
  
  it "should implement a default unauthorized method" do
    Autumn::Authentication::Base.instance_methods.should include('unauthorized')
  end
end

describe Autumn::Authentication::Op do
  before :each do
    @sender_hash = { :nick => 'Nick', :user => 'User', :host => 'example.com' }
    @stem = Object.new
  end
  
  it "should be a subclass of Autumn::Authentication::Base" do
    Autumn::Authentication::Op.ancestors.should include(Autumn::Authentication::Base)
  end
  
  describe "with the default options" do
    before :each do
      @auth = Autumn::Authentication::Op.new
    end
    
    it "should not authenticate unvoiced channel members" do
      @stem.stub!(:privilege).and_return(:unvoiced)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_false
    end
    
    it "should not authenticate voiced channel members" do
      @stem.stub!(:privilege).and_return(:voiced)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_false
    end
    
    it "should not authenticate half-ops" do
      @stem.stub!(:privilege).and_return(:halfop)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_false
    end
    
    it "should authenticate ops" do
      @stem.stub!(:privilege).and_return(:op)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_true
    end
    
    it "should authenticate admins" do
      @stem.stub!(:privilege).and_return(:admin)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_true
    end
    
    it "should authenticate owners" do
      @stem.stub!(:privilege).and_return(:channel_owner)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_true
    end
  end
  
  describe "with custom options" do
    before :each do
      @auth = Autumn::Authentication::Op.new :privileges => [ :unvoiced, :op ]
    end
    
    it "should authenticate unvoiced channel members" do
      @stem.stub!(:privilege).and_return(:unvoiced)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_true
    end
    
    it "should not authenticate voiced channel members" do
      @stem.stub!(:privilege).and_return(:voiced)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_false
    end
        
    it "should authenticate ops" do
      @stem.stub!(:privilege).and_return(:op)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_true
    end
    
    it "should not authenticate admins" do
      @stem.stub!(:privilege).and_return(:admin)
      @auth.authenticate(@stem, '#channel', @sender_hash, nil).should be_false
    end
  end
end

describe Autumn::Authentication::Nick do
  it "should raise an exception when initialized with no nicks" do
    lambda { Autumn::Authentication::Nick.new }.should raise_error
  end
  
  it "should not raise an exception when initialized with a nick" do
    lambda { Autumn::Authentication::Nick.new :nick => 'Nick' }.should_not raise_error
  end
  
  it "should not raise an exception when initialized with an array of nicks" do
    lambda { Autumn::Authentication::Nick.new :nicks => [ 'Nick1', 'Nick2' ] }.should_not raise_error
  end
  
  describe "initialized with a single nick" do
    before :each do
      @auth = Autumn::Authentication::Nick.new(:nick => 'Nick2')
    end
    
    it "should authenticate an authorized nick" do
      @auth.authenticate(nil, nil, { :nick => 'Nick2' }, nil).should be_true
    end
    
    it "should not authenticate an unauthorized nick" do
      @auth.authenticate(nil, nil, { :nick => 'Nick3' }, nil).should be_false
    end
  end
  
  describe "initialized with multiple nicks" do
    before :each do
      @auth = Autumn::Authentication::Nick.new(:nicks => [ 'Nick1', 'Nick2' ])
    end
    
    it "should authenticate an authorized nick" do
      @auth.authenticate(nil, nil, { :nick => 'Nick2' }, nil).should be_true
    end
    
    it "should not authenticate an unauthorized nick" do
      @auth.authenticate(nil, nil, { :nick => 'Nick3' }, nil).should be_false
    end
  end
end

describe Autumn::Authentication::Hostname do
  it "should raise an exception when initialized with no hosts" do
    lambda { Autumn::Authentication::Hostname.new }.should raise_error
  end
  
  it "should not raise an exception when initialized with a host" do
    lambda { Autumn::Authentication::Hostname.new :host => 'host1.com' }.should_not raise_error
  end
  
  it "should not raise an exception when initialized with an array of hosts" do
    lambda { Autumn::Authentication::Hostname.new :hosts => [ 'host1.com', 'host2.com' ] }.should_not raise_error
  end
  
  describe "with the default hostmask" do
    describe "initialized with a single host" do
      before :each do
        @auth = Autumn::Authentication::Hostname.new(:host => 'ca.host1.com')
      end
    
      it "should authenticate an authorized host" do
        @auth.authenticate(nil, nil, { :host => 'wsd1.ca.host1.com' }, nil).should be_true
      end
    
      it "should not authenticate an unauthorized host" do
        @auth.authenticate(nil, nil, { :host => 'unauthorized' }, nil).should be_false
      end
    end
    
    describe "initialized with multiple hosts" do
      before :each do
        @auth = Autumn::Authentication::Hostname.new(:hosts => [ 'host1.com', 'ca.host2.com' ])
      end
    
      it "should authenticate an authorized host" do
        @auth.authenticate(nil, nil, { :host => 'wsd1.ca.host2.com' }, nil).should be_true
      end
    
      it "should not authenticate an unauthorized host" do
        @auth.authenticate(nil, nil, { :host => 'unauthorized' }, nil).should be_false
      end
    end
  end
  
  describe "with custom String hostmask" do
    before :each do
      @auth = Autumn::Authentication::Hostname.new(:hosts => [ '1', '2' ], :hostmask => 'host(\d)\.com')
    end
    
    it "should authenticate an authorized host" do
      @auth.authenticate(nil, nil, { :host => 'host2.com' }, nil).should be_true
    end
    
    it "should not authenticate an unauthorized host" do
      @auth.authenticate(nil, nil, { :host => 'host3.com' }, nil).should be_false
    end
  end
  
  describe "with custom Regexp hostmask" do
    before :each do
      @auth = Autumn::Authentication::Hostname.new(:hosts => [ '1', '2' ], :hostmask => /host(\d)\.com/)
    end
    
    it "should authenticate an authorized host" do
      @auth.authenticate(nil, nil, { :host => 'host2.com' }, nil).should be_true
    end
    
    it "should not authenticate an unauthorized host" do
      @auth.authenticate(nil, nil, { :host => 'host3.com' }, nil).should be_false
    end
  end
  
  describe "with custom Proc hostmask" do
    before :each do
      @auth = Autumn::Authentication::Hostname.new(:host => 'com', :hostmask => Proc.new { |h| h.split('.').last })
    end
    
    it "should authenticate an authorized host" do
      @auth.authenticate(nil, nil, { :host => 'host.com' }, nil).should be_true
    end
    
    it "should not authenticate an unauthorized host" do
      @auth.authenticate(nil, nil, { :host => 'host.net' }, nil).should be_false
    end
  end
end
