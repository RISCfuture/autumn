require 'rubygems'

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
