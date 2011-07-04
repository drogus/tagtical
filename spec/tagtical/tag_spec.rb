require File.expand_path('../../spec_helper', __FILE__)

describe @klass do

  before do
    clean_database!
    @klass = Tagtical::Tag
    @tag = @klass.new(:value => "train")
  end

  subject { @tag }

  it { should be_valid }

  its(:count) { should == 0 }
  its(:to_s) { should == @tag.value }

  describe(".sti_name") do
    specify { @klass.sti_name == "tag" }
  end

  its(:type) { should be_nil }

  describe ".find_sti_class" do
    specify do
      {"skill" => Tag::Skill, "tag" => @klass}.each do |arg, result|
        @klass.send(:find_sti_class, arg).should == result
      end
    end
  end

  describe "sort" do
    before do
      @tag1 = @klass.new(:value => "car").tap { |x| x["relevance"] = "2.5" }
      @tag2 = @klass.new(:value => "plane").tap { |x| x["relevance"] = "1.7" }
      @tag3 = @klass.new(:value => "bike").tap { |x| x["relevance"] = "1.1" }
      @tags = [@tag1, @tag2, @tag3]
    end
    
    it "should sort by relevance if all tags have them" do
      @tags.sort.map(&:value).should == ["bike", "plane", "car"]
    end

    it "should fallback gracefully when relevance not provided" do
      @tag3["relevance"] = nil
      @tags.sort.map(&:value).should == ["bike", "plane", "car"]
    end

    it "should sort by value when no relevances provided" do
      @tags.each { |t| t["relevance"] = nil }
      @tags.sort.map(&:value).should == ["bike", "car", "plane"]
    end
  end

  describe "#==" do
    it { should == @tag }
    it { should_not == "tain" }
    it { should_not == @klass.new }
  end

  describe "#find_or_create_tags" do
    before(:each) do
      @klass.create!(:value => "awesome")
      @klass.create!(:value => "epic")
    end

    it "should find both tags" do
      lambda {
        @klass.find_or_create_tags("awesome", "epic")
      }.should change(@klass, :count).by(0)
    end
  end

  describe "#where_any_like" do
    before do
      @klass.create!(:value => "awesome")
      @klass.create!(:value => "epic")
    end

    it "should find both tags wildcard search" do
      @klass.where_any_like(["awe", "epic"], :wildcard => true).should have(2).items
    end

    it "should not be case sensitive" do
      @klass.where_any_like(["AWESOME", "EpIc"]).should have(2).items
    end
  
  end

  describe ".find_or_create_with_like_by_value!" do
    before do
      @tag.value = "awesome"
      @tag.save
    end

    it "should find by name" do
      @klass.find_or_create_with_like_by_value!("awesome").should == @tag
    end

    it "should find by name case insensitive" do
      @klass.find_or_create_with_like_by_value!("AWESOME").should == @tag
    end

    it "should create by name" do
      lambda {
        @klass.find_or_create_with_like_by_value!("epic")
      }.should change(@klass, :count).by(1)
    end
  end

  describe ".find_or_create_tags" do
    before(:each) do
      @tag.value = "awesome"
      @tag.save!
    end

    it "should find by name" do
      @klass.find_or_create_tags("awesome").should == {@tag => "awesome"}
    end

    it "should find by name case insensitive" do
      @klass.find_or_create_tags("AWESOME").should == {@tag => "AWESOME"}
    end

    it "should create by name" do
      lambda {
        @klass.find_or_create_tags("epic")
      }.should change(@klass, :count).by(1)
    end

    it "should find or create by name" do
      lambda {
        @klass.find_or_create_tags("awesome", "epic").keys.map(&:value).should == ["awesome", "epic"]
      }.should change(@klass, :count).by(1)
    end

    it "should return an empty array if no tags are specified" do
      @klass.find_or_create_tags([]).should == {}
    end
  end

  it "should require a name" do
    @tag.value = nil
    @tag.valid?

    if ActiveRecord::VERSION::MAJOR >= 3
      @tag.errors[:value].should == ["can't be blank"]
    else
      @tag.errors[:value].should == "can't be blank"
    end

    @tag.value = "something"
    @tag.valid?

    if ActiveRecord::VERSION::MAJOR >= 3
      @tag.errors[:value].should == []
    else
      @tag.errors[:value].should be_nil
    end
  end

  it "#where_any" do
    @tag.value = "cool"
    @tag.save!
    @klass.where_any('cool').should include(@tag)
  end

  describe "Type" do
    before do
      @klass = @klass::Type
      @type = @klass.new("skill")
    end
    subject { @type }

    its(:klass) { should == Tag::Skill }
    its(:scope_name) { should == :skills }

    describe "initialize" do
      it "converts string into correct format" do
        {"ClassNames" => "class_name", "photo_tags" => "photo", :photo => "photo"}.each do |input, result|
          @klass.new(input).should == result
        end
      end
    end

    describe ".[]" do
      specify { @klass[@type].should equal @type }
      specify { @klass["foo"].should be_a @klass }
    end

    describe "#==" do
      {"foo" => false, "skill" => true, Tagtical::Tag::Type.new("skill") => true}.each do |obj, result|
        specify { (subject==obj).should==result }
      end
    end

    describe "#derive_class_candidates" do
      specify do
        subject.send(:derive_class_candidates).should include(
          "Tagtical::Tag::Skill", "Tag::Skill", "Skill",
            "Tagtical::Tag::SkillTag", "Tag::SkillTag", "SkillTag"
        )
      end
    end

    describe "#tag_list_name" do
      context "when prefix is not specified" do
        its(:tag_list_name) { should == "skill_list" }
      end
      context "when prefix is specified" do
        specify { subject.tag_list_name(:all).should == "all_skill_list" }
      end
    end

    context "when type is 'Tag'" do
      before { @type = @klass.new("tag") }
      its(:klass) { should == Tagtical::Tag }
      its(:scope_name) { should == :tags }
    end

  end
end
