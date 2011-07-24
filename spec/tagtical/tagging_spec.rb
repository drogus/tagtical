require File.expand_path('../../spec_helper', __FILE__)

describe Tagtical::Tagging do
  before(:each) do
    clean_database!
    @klass = Tagtical::Tagging
    @tagging = @klass.new(:relevance => 4.0)
  end
  subject { @tagging }

  describe "#before_create" do
    context "when no relevance set" do
      before do
        @tagging.relevance = nil
        @tagging.run_callbacks(:create)
      end
      its(:relevance) { should == @klass.default_relevance }
    end
    context "when relevance set" do
      before { @tagging.run_callbacks(:create) }
      its(:relevance) { should == @tagging.relevance }
    end
  end

  it "should sort by relevance" do
    @taggings = [3.454, 2.3, 6, 3.2].map { |relevance| @klass.new(:relevance => relevance) }
    @taggings.sort.map(&:relevance).should == [2.3, 3.2, 3.454, 6.0]
  end

  it "should not be valid with a invalid tag" do
    @tagging.taggable = TaggableModel.create(:name => "Bob Jones")
    @tagging.tag = Tagtical::Tag.new(:value => "") 

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
      2.times { @klass.create(:taggable => @taggable, :tag => @tag, :context => 'tags') }
    }.should change(@klass, :count).by(1)
  end

  describe "#set_tag_target" do
    before do
      @tag = Tagtical::Tag.new(:value => "foo")
      @tagging.set_tag_target(@tag)
    end

    it "should set relevance on tag" do
      @tagging.tag.relevance.should==4.0
    end
  end

end
