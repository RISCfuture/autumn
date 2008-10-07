require 'rubygems'
require 'facets/symbol'
require 'dm-core'

require 'libs/misc'
require 'libs/datamapper_hacks'

describe DataMapper::Resource do
  describe "within a module" do
    before :each do
      module Blog
        class Post
          include DataMapper::Resource
          property :id, Integer, :serial => true
          has n, :categories, :through => Resource
          has 1, :content
          belongs_to :author
        end
      
        class Content
          include DataMapper::Resource
          property :id, Integer, :serial => true
          belongs_to :post
        end
      
        class Author
          include DataMapper::Resource
          property :id, Integer, :serial => true
          has n, :posts
        end
      
        class Category
          include DataMapper::Resource
          property :id, Integer, :serial => true
          has n, :posts, :through => Resource
        end
      end
    end
  
    def class_name(relationship)
      relationship.options.fetch(:class_name, Extlib::Inflection.classify(relationship.name))
    end
  
    it "should include the module name in the class name in one-to-many associations" do
      class_name(Blog::Author.relationships[:posts]).should eql("Blog::Post")
    end
  
    it "should include the module name in the class name in one-to-one associations" do
      class_name(Blog::Post.relationships[:content]).should eql("Blog::Content")
      class_name(Blog::Content.relationships[:post]).should eql("Blog::Post")
    end
  
    it "should include the module name in the class name in many-to-one associations" do
      class_name(Blog::Post.relationships[:author]).should eql("Blog::Author")
    end
  
    it "should not include the module name in the class name in many-to-many associations" do
      class_name(Blog::Post.relationships[:categories]).should eql("CategoryPost")
      class_name(Blog::Category.relationships[:posts]).should eql("CategoryPost")
    end
  
    it "should define a many-to-many DataMapper resource in the module" do
      Blog.constants.should include("CategoryPost")
    end
  
    after :each do
      Object.send :remove_const, :Blog
    end
  end

  describe "with a a many_to_many relationship" do
    before :each do
      class Post
        include DataMapper::Resource
        property :id, Integer, :serial => true
        has n, :categories, :through => Resource
      end
    
      class Category
        include DataMapper::Resource
        property :id, Integer, :serial => true
        has n, :posts, :through => Resource
      end
    end
  
    it "should define a join model" do
      Object.constants.should include("CategoryPost")
    end
  
    it " ... with appropriate relationships" do
      CategoryPost.many_to_one_relationships.collect(&:name).to_set.should == [ :category, :post ].to_set
    end
  
    after :each do
      [ :Post, :Category, :CategoryPost ].each { |const| Object.send(:remove_const, const) }
    end
  end

  describe "scoped to a repository other than its default" do
    before :each do
      DataMapper.setup(:other, "sqlite3::memory:")
      repository(:other) do
        class Post
          include DataMapper::Resource
          property :id, Integer, :serial => true
          has n, :categories, :through => Resource
        end
      
        class Category
          include DataMapper::Resource
          property :id, Integer, :serial => true
          has n, :posts, :through => Resource
        end
      end
    end
  
    it "should use the scoped repository for the near_relationship method" do
      Post.relationships(:other)[:categories].near_relationship.should be_nil
      repository(:other) { Post.relationships(:other)[:categories].near_relationship.should_not be_nil }
    end
  
    it "should use the scoped repository for the remote_relationship method" do
      Post.relationships(:other)[:categories].remote_relationship.should be_nil
      repository(:other) { Post.relationships(:other)[:categories].remote_relationship.should_not be_nil }
    end
  
    it "should use the given repository for the properties_with_subclasses method" do
      CategoryPost.properties_with_subclasses(:default).should be_empty
      CategoryPost.properties_with_subclasses(:other).should_not be_empty
    end
  
    after :each do
      [ :Post, :Category, :CategoryPost ].each { |const| Object.send(:remove_const, const) }
    end
  end
end

describe DataMapper::Repository do
  before :each do
    GC.start
    repository(:other) do
      class Post
        include DataMapper::Resource
        property :id, Integer, :serial => true
        has n, :categories, :through => Resource
      end
  
      class Category
        include DataMapper::Resource
        property :id, Integer, :serial => true
        has n, :posts, :through => Resource
      end
    end
  end
  
  it "should define a models method that returns all models defined for this repository" do
    repository(:other).models.should include(Post, Category)
    repository(:default).models.should_not include(Post, Category)
  end
  
  after :each do
    [ :Post, :Category, :CategoryPost ].each { |const| Object.send(:remove_const, const) }
  end
end
