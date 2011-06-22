require File.expand_path('../../spec_helper', __FILE__)

describe Tagtical::Tag do
  before(:each) do
    clean_database!
    @tag = Tagtical::Tag.new
    @user = TaggableModel.create(:name => "Pablo")
  end

  describe "named like any" do
    before(:each) do
      Tagtical::Tag.create(:name => "awesome")
      Tagtical::Tag.create(:name => "epic")
    end

    it "should find both tags" do
      Tagtical::Tag.named_like_any(["awesome", "epic"]).should have(2).items
    end
  end

  describe "find or create by name" do
    before(:each) do
      @tag.value = "awesome"
      @tag.save
    end

    it "should find by name" do
      Tagtical::Tag.find_or_create_with_like_by_name("awesome").should == @tag
    end

    it "should find by name case insensitive" do
      Tagtical::Tag.find_or_create_with_like_by_name("AWESOME").should == @tag
    end

    it "should create by name" do
      lambda {
        Tagtical::Tag.find_or_create_with_like_by_name("epic")
      }.should change(Tagtical::Tag, :count).by(1)
    end
  end

  describe "find or create all by any name" do
    before(:each) do
      @tag.value = "awesome"
      @tag.save
    end

    it "should find by name" do
      Tagtical::Tag.find_or_create_all_with_like_by_value("awesome").should == [@tag]
    end

    it "should find by name case insensitive" do
      Tagtical::Tag.find_or_create_all_with_like_by_value("AWESOME").should == [@tag]
    end

    it "should create by name" do
      lambda {
        Tagtical::Tag.find_or_create_all_with_like_by_value("epic")
      }.should change(Tagtical::Tag, :count).by(1)
    end

    it "should find or create by name" do
      lambda {
        Tagtical::Tag.find_or_create_all_with_like_by_value("awesome", "epic").map(&:name).should == ["awesome", "epic"]
      }.should change(Tagtical::Tag, :count).by(1)
    end

    it "should return an empty array if no tags are specified" do
      Tagtical::Tag.find_or_create_all_with_like_by_value([]).should == []
    end
  end

  it "should require a name" do
    @tag.valid?
    
    if ActiveRecord::VERSION::MAJOR >= 3
      @tag.errors[:name].should == ["can't be blank"]
    else
      @tag.errors[:name].should == "can't be blank"
    end

    @tag.value = "something"
    @tag.valid?
    
    if ActiveRecord::VERSION::MAJOR >= 3      
      @tag.errors[:name].should == []
    else
      @tag.errors[:name].should be_nil
    end
  end

  it "should equal a tag with the same name" do
    @tag.value = "awesome"
    new_tag = Tagtical::Tag.new(:name => "awesome")
    new_tag.should == @tag
  end

  it "should return its name when to_s is called" do
    @tag.value = "cool"
    @tag.to_s.should == "cool"
  end

  it "have named_scope named(something)" do
    @tag.value = "cool"
    @tag.save!
    Tagtical::Tag.named('cool').should include(@tag)
  end

  it "have named_scope named_like(something)" do
    @tag.value = "cool"
    @tag.save!
    @another_tag = Tagtical::Tag.create!(:name => "coolip")
    Tagtical::Tag.named_like('cool').should include(@tag, @another_tag)
  end
end
