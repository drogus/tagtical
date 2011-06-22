require File.expand_path('../../spec_helper', __FILE__)

describe Tagtical::Tagging do
  before(:each) do
    clean_database!
    @tagging = Tagtical::Tagging.new
  end

  it "should not be valid with a invalid tag" do
    @tagging.taggable = TaggableModel.create(:name => "Bob Jones")
    @tagging.tag = Tagtical::Tag.new(:value => "")
    @tagging.context = "tags"

    @tagging.should_not be_valid
    
    if ActiveRecord::VERSION::MAJOR >= 3
      @tagging.errors[:tag_id].should == ["can't be blank"]
    else
      @tagging.errors[:tag_id].should == "can't be blank"
    end
  end

  it "should not create duplicate taggings" do
    @taggable = TaggableModel.create(:name => "Bob Jones")
    @tag = Tagtical::Tag.create(:value => "awesome")

    lambda {
      2.times { Tagtical::Tagging.create(:taggable => @taggable, :tag => @tag, :context => 'tags') }
    }.should change(Tagtical::Tagging, :count).by(1)
  end
end
