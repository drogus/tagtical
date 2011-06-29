require File.expand_path('../../spec_helper', __FILE__)

describe @klass do

  before do
    clean_database!
    @klass = Tagtical::Tag
    @tag = @klass.new(:value => "train", :relevance => 3.5)
  end

  subject { @tag }

  it { should be_valid }

  its(:count) { should == 0 }
  its(:to_s) { should == @tag.value }

  describe(".sti_name") do
    specify { @klass.sti_name == "tag" }
  end

  describe "#before_create" do
    context "when no relevance set" do
      before do
        @tag.relevance = nil
        @tag.run_callbacks(:create)
      end
      its(:relevance) { should == @klass.default_relevance }
    end
    context "when relevance set" do
      before { @tag.run_callbacks(:create) }
      its(:relevance) { should == @tag.relevance }
    end
  end

  its(:type) { should == "tag" }

  describe ".find_sti_class" do
    specify do
      {"inheriting" => Tag::Inheriting, "tag" => @klass}.each do |arg, result|
        @klass.send(:find_sti_class, arg).should == result
      end
    end
  end

  describe "#==" do
    it { should == @tag }
    it { should_not == "tain" }
    it { should_not == @klass.new }
  end

  it  "should sort by relevance" do
    @tags = [3.454, 2.3, 6, 3.2].map { |relevance| @klass.new(:relevance => relevance) }
    @tags.sort.map(&:relevance).should == [2.3, 3.2, 3.454, 6.0]
  end

  describe "#find_or_create_tag_list" do
    before(:each) do
      @klass.create!(:value => "awesome")
      @klass.create!(:value => "epic")
    end

    it "should find both tags" do
      lambda {
        @klass.find_or_create_tag_list("awesome", "epic")
      }.should change(@klass, :count).by(0)
    end
  end

  describe "#where_any_like" do
    before do
      @klass.create!(:value => "awesome")
      @klass.create!(:value => "epic")
    end

    it "should find both tags" do
      @klass.where_any_like(["awe", "epic"]).should have(2).items
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

  describe ".find_or_create_tag_list" do
    before(:each) do
      @tag.value = "awesome"
      @tag.save!
    end

    it "should find by name" do
      @klass.find_or_create_tag_list("awesome").should == [@tag]
    end

    it "should find by name case insensitive" do
      @klass.find_or_create_tag_list("AWESOME").should == [@tag]
    end

    it "should create by name" do
      lambda {
        @klass.find_or_create_tag_list("epic")
      }.should change(@klass, :count).by(1)
    end

    it "should find or create by name" do
      lambda {
        @klass.find_or_create_tag_list("awesome", "epic").map(&:value).should == ["awesome", "epic"]
      }.should change(@klass, :count).by(1)
    end

    it "should return an empty array if no tags are specified" do
      @klass.find_or_create_tag_list([]).should == []
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

  it "where_any_like" do
    @tag.value = "cool"
    @tag.save!
    @another_tag = @klass.create!(:value => "coolip")
    @klass.where_any_like('cool').should include(@tag, @another_tag)
  end

  describe "Type" do
    before do
      @klass = @klass::Type
      @type = @klass.new("inheriting")
    end
    subject { @type }

    its(:klass) { should == Tag::Inheriting }
    its(:class_name) { should == "Inheriting" }
    its(:scope_name) { should == "inheriting" }

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
      {"foo" => false, "inheriting" => true, Tagtical::Tag::Type.new("inheriting") => true}.each do |obj, result|
        specify { (subject==obj).should==result }
      end
    end

    describe "#tag_list_name" do
      context "when prefix is not specified" do
        its(:tag_list_name) { should == "inheriting_list" }
      end
      context "when prefix is specified" do
        specify { subject.tag_list_name(:all).should == "all_inheriting_list" }
      end
    end

    context "when type is 'Tag'" do
      before { @type = @klass.new("tag") }
      its(:klass) { should == Tagtical::Tag }

      its(:class_name) { should == "Tag" }
      its(:scope_name) { should == "tag" }
    end

  end

end
