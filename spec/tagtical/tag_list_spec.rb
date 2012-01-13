require File.expand_path('../../spec_helper', __FILE__)

describe Tagtical::TagList do
  before do
    @klass = Tagtical::TagList
    @tag_list = @klass.new("awesome", "radical")
  end

  subject { @tag_list }

  it { should be_an Array }

  specify do
    @tag_list.each do |value|
      value.should be_an_instance_of Tagtical::TagList::TagValue
      value.relevance.should be_nil
    end
  end

  describe ".from" do

    it "should accept a hash with relevance values" do
      @tag_list = @klass.from("tag 1" => 4.5, "tag 2" => 4.454)
      @tag_list.map(&:relevance).should == [4.5, 4.454]
    end

    it "should accept nil" do
      @tag_list = @klass.from(nil)
      @tag_list.empty?.should be_true
    end
    
  end

  it "should convert all values to Tagtical::TagList::TagValue" do
    @tag_list << "foo"
    @tag_list.concat(["bar"])
    @tag_list.each do |value|
      value.should be_an_instance_of Tagtical::TagList::TagValue
    end
  end

  it "should be able to be add a new tag word" do
    @tag_list.add("cool")
    @tag_list.include?("cool").should be_true
  end

  it "should be able to add delimited lists of words" do
    @tag_list.add("cool, wicked")
    @tag_list.should include("cool", "wicked")
  end

  it "should be able to edit relevance of an existing tag" do
    @tag_list.add("cool" => 0.3)
    @tag_list.add("cool" => 0.6)
    
    @tag_list.detect { |t| t=="cool" }.relevance.should == 0.6
  end

  it "should be able to add delimited list of words with quoted delimiters" do
    @tag_list.add("'cool, wicked', \"really cool, really wicked\"")
    @tag_list.should include("cool, wicked", "really cool, really wicked")
  end

  it "should be able to handle other uses of quotation marks correctly" do
    @tag_list.add("john's cool car, mary's wicked toy")
    @tag_list.should include("john's cool car", "mary's wicked toy")
  end

  it "should be able to add an array of words" do
    @tag_list.add(["cool", "wicked"])
    @tag_list.should include("cool", "wicked")
  end

  it "should be able to add a hash" do
    @tag_list.add("crazy" => 0.45, "narly" => 5.4)
    @tag_list.should include("crazy", "narly")
    @tag_list.detect { |t| t=="crazy" }.relevance.should == 0.45
  end

  it "should be able to add relevances with a string" do
    @tag_list.add("foo : 3.4, bar: 2.5")
    @tag_list.find("foo").relevance.should == 3.4
    @tag_list.find("bar").relevance.should == 2.5
  end

  it "should be able to add a symbol" do
    @tag_list.add(:car)
    @tag_list.find("car").should_not be_nil
  end

  it "should be able to add a list of tags" do
    tags = [["foo", 1],["bar", 1.3],["car", 0.7]].map do |value, relevance|
      Tagtical::Tag.new(:value => value, :relevance => relevance)
    end
    @tag_list.add(tags)
    tags.each do |tag|
      @tag_list.find(tag.value).relevance.should == tag.relevance
    end
  end

  it "should be able to remove words" do
    @tag_list.remove("awesome")
    @tag_list.include?("awesome").should be_false
  end

  it "should be able to remove delimited lists of words" do
    @tag_list.remove("awesome, radical")
    @tag_list.should be_empty
  end

  it "should be able to remove an array of words" do
    @tag_list.remove(["awesome", "radical"])
    @tag_list.should be_empty
  end

  its(:to_s) { should == "awesome, radical" }

  describe "#to_s" do
    before do
      @tag_list = Tagtical::TagList.new("far", "awesome : 4", "radical : 3", "car, bar:10.3", :parse => false)
      @taggable = TaggableModel.new
      @taggable.set_tag_list "retro: 6, car:4, nature, test: 2.7 ", :cascade => true
      @taggable.save
      @taggable.reload
    end

    it "should keep quotations in words when parse is false" do
      @tag_list.to_s.should include(%{"car, bar"})
    end

    it "should not include relevance in string" do
      @taggable.tag_list.to_s.should == "retro, car, nature, test"
    end

    context "when :relevance is specified" do

      it "should contain relevance with the relevance delimiter" do
        @tag_list.to_s(:relevance).should include("awesome:4.0, radical:3.0")
      end

      it "should keep quotations in words when parse is false" do
        @tag_list.to_s(:relevance).should include(%{"car, bar":10.3})
      end

      it "should include relevance in string" do
        @taggable.tag_list.to_s(:relevance).should == "retro:6.0, car:4.0, nature:1.0, test:2.7"
      end

    end
  
  end

  it "should quote escape tags with commas in them" do
    @tag_list.add("cool","rad,bodacious", :parse => false)
    @tag_list.to_s.should == "awesome, radical, cool, \"rad,bodacious\""
  end

  it "should be able to call to_s on a frozen tag list" do
    @tag_list.freeze
    lambda { @tag_list.add("cool","rad,bodacious") }.should raise_error
    lambda { @tag_list.to_s }.should_not raise_error
  end

  describe "TagValue" do
    before do
      @tag_value = Tagtical::TagList::TagValue.new("sweetness", @relevance = 3.2)
    end
    subject { @tag_value }

    its(:relevance) { should == @relevance }

  end
  
end
