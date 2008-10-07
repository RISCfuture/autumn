require 'rubygems'
require 'facets/array'
require 'facets/string'

require "libs/coder"

describe Autumn::Coder do
  before :each do
    @coder = Autumn::Coder.new
  end
  
  it "should start with an indent of 0" do
    @coder << "test string"
    @coder.output.should eql("test string\n")
  end
  
  it "should indent by two spaces" do
    @coder.indent!
    @coder << "test string"
    @coder.unindent!
    @coder.output.should eql("  test string\n")
  end
  
  it "should indent each line of a multi-line string" do
    @coder.indent!
    @coder << "line 1\nline 2"
    @coder.unindent!
    @coder.output.should eql("  line 1\n  line 2\n")
  end
  
  it "should insert a newline between consecutive calls to <<" do
    @coder << "first string"
    @coder << "second string"
    @coder.output.should eql("first string\nsecond string\n")
  end
  
  it "should unindent by two spaces" do
    @coder.indent!
    @coder << "first string"
    @coder.unindent!
    @coder << "second string"
    @coder.output.should eql("  first string\nsecond string\n")
  end
  
  it "should add newlines when given the newline! message" do
    @coder << "first line"
    @coder.newline!
    @coder << "second line"
    @coder.output.should eql("first line\n\nsecond line\n")
  end
  
  it "should generate a basic class template" do
    @coder.klass('TestClass')
    @coder.output.should eql("class TestClass\nend\n")
  end
  
  it "should generate a subclass template" do
    @coder.klass('Subclass', 'Superclass')
    @coder.output.should eql("class Subclass < Superclass\nend\n")
  end
  
  it "should indent the contents of a class" do
    @coder.klass('TestClass') { |klass| klass << "content" }
    @coder.output.should eql("class TestClass\n  content\nend\n")
  end
  
  it "should generate a basic method template" do
    @coder.method('test_method')
    @coder.output.should eql("def test_method\nend\n")
  end
  
  it "should indent the contents of a method" do
    @coder.method('test_method') { |meth| meth << "content" }
    @coder.output.should eql("def test_method\n  content\nend\n")
  end
  
  it "should properly generate a one-parameter method" do
    @coder.method('test_method', :arg)
    @coder.output.should eql("def test_method(arg)\nend\n")
  end
  
  it "should properly generate a multi-parameter method" do
    @coder.method('test_method', :arg1, :arg2)
    @coder.output.should eql("def test_method(arg1, arg2)\nend\n")
  end
  
  it "should properly generate optional parameters" do
    @coder.method('test_method', { :arg => nil })
    @coder.output.should eql("def test_method(arg=nil)\nend\n")
  end
  
  it "should properly generate multiple optional and required parameters" do
    @coder.method('test_method', :req1, :req2, { :opt1 => '' }, { :opt2 => Array.new })
    @coder.output.should eql(%{def test_method(req1, req2, opt1="", opt2=[])\nend\n})
  end
  
  it "should raise an exception for empty parameter names" do
    lambda { @coder.method('test_method', '') }.should raise_error(ArgumentError)
  end
  
  it "should raise an exception for empty optional parameter names" do
    lambda { @coder.method('test_method', { '' => nil }) }.should raise_error(ArgumentError)
  end
end

describe Autumn::TemplateCoder do
  before :each do
    @coder = Autumn::TemplateCoder.new
  end
  
  it "should generate a proper leaf template" do
    @coder.leaf('test_leaf')
    
    # HACK extlib and facets both define String#margin to do different things;
    #      we need a way to un-require the dm-core gem once we've run the DM
    #      specs. For now, we're forced to redefine String#margin
    String.class_eval do
      def margin(n=0)
        #d = /\A.*\n\s*(.)/.match( self )[1]
        #d = /\A\s*(.)/.match( self)[1] unless d
        d = ((/\A.*\n\s*(.)/.match(self)) ||
            (/\A\s*(.)/.match(self)))[1]
        return '' unless d
        if n == 0
          gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, '')
        else
          gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, ' ' * n)
        end
      end
    end
    
    @coder.output.should eql(%{
      |# Controller for the TestLeaf leaf.
      |
      |class Controller < Autumn::Leaf
      |  
      |  # Typing "!about" displays some basic information about this leaf.
      |  
      |  def about_command(stem, sender, reply_to, msg)
      |    # This method renders the file "about.txt.erb"
      |  end
      |end
      |
    }.margin)
  end
end
