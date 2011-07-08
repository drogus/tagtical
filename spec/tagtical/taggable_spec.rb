require File.expand_path('../../spec_helper', __FILE__)
describe Tagtical::Taggable do
  before do
    clean_database!
    @taggable = TaggableModel.new(:name => "Bob Jones")
    @taggables = [@taggable, TaggableModel.new(:name => "John Doe")]
  end
  it "should be able to select taggables by subset of tags using ActiveRelation methods" do
    @taggables[0].tag_list = "bob"
    @taggables[1].tag_list = "charlie"
    @taggables[0].skill_list = "ruby"
    @taggables[1].skill_list = "css"
    @taggables[0].craft_list = "knitting"
    @taggables[1].craft_list = "pottery"
    @taggables.each(&:save!)

    TaggableModel.tags("bob").should == [@taggables[0]]
    TaggableModel.skills("ruby").should == [@taggables[0]]
    TaggableModel.tags("ruby").should == [@taggables[0]]
    TaggableModel.skills("knitting").should == [@taggables[0]]
    TaggableModel.skills("knitting", :only => :current).should == []
    TaggableModel.skills("knitting", :only => :parents).should == []
    TaggableModel.tags("bob", :only => :current).should == [@taggables[0]]
    TaggableModel.skills("bob", :only => :parents).should == [@taggables[0]]
    TaggableModel.crafts("knitting").should == [@taggables[0]]
    end
end
