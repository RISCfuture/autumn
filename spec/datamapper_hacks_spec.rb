require 'rubygems'
require 'dm-core'

require 'libs/misc'
require 'libs/datamapper_hacks'

module Blog
  class Post
    include DataMapper::Resource
    has n, :categories, :through => Resource
    has 1, :content
    belongs_to :author
  end
  
  class Content
    include DataMapper::Resource
    belongs_to :post
  end
  
  class Author
    include DataMapper::Resource
    has n, :posts
  end
  
  class Category
    include DataMapper::Resource
    has n, :posts, :through => Resource
  end
end

describe "a DataMapper instance within a module" do
  
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
end
