require File.expand_path('../../spec_helper', __FILE__)

describe Tagtical::Tag do

  before do
    clean_database!
    @klass = Tagtical::Tag
    @tag = @klass.new(:value => "train")
  end

  subject { @tag }

  it { should be_valid }

  its(:count) { should == 0 }
  its(:to_s) { should == @tag.value }

  specify { @klass.sti_name.should be_nil }

  its(:type) { should be_nil }

  describe "validations" do

    it "should require a value" do
      {"" => 1, nil => 1, "foo" => 0}.each do |value, error_count|
        @tag.value = value
        @tag.valid?
        @tag.errors[:value].should have(error_count).items
      end
    end

    it "should be unique on value and type" do
      lambda {
        Tag::Skill.create!(:value => "foo")
        Tag::FooCraft.create!(:value => "foo")
      }.should change(@klass, :count).by(2)
    end

    when_possible_values_specified do

      it "should not be valid if value is not in possible_values" do
        @tag.value = "glass"
        @tag.should be_invalid
        @tag.errors[:value][0].should == %{"glass" not found in list: ["knife", "fork", "spoon"]}
      end

      it "should be valid even if cases are different" do
        @tag.value = "Knife"
        @tag.should be_valid
      end

    end

  end

  describe "Questioner Methods" do

    before do
      @tag = Tag::FooCraft.new(:value => "foo")
    end

    it "should have methods to question the tag type" do
      should be_skill
      should be_craft
      should be_tag
      should_not be_offering
    end

    it "should have methods on the class to question the tag type" do
      @tag.class.should be_skill
      @tag.class.should be_craft
      @tag.class.should be_tag
      @tag.class.should_not be_offering
    end

    context "before methods are defined" do
      before do
        @types = [:craft?, :skill?, :tag?]
        @types.each { |x| @tag.class.send(:undef_method, x) if @tag.class.instance_methods.include?(x) }
      end

      it "should respond_to?" do
        @types.each { |m| @tag.respond_to?(m).should be_true }
      end

      it "should respond_to correctly for incorrect methods" do
        @tag.respond_to?(:foo).should be_false
      end

    end
  end

  when_possible_values_specified do

    it "should use values from possible_values" do
      @tag.value = "SPOON"
      @tag.save!
      @tag.reload
      @tag.value.should == "spoon"
    end
    
  end

  describe ".type" do

    it "should accept :scope condition as argument" do
      @klass::Type.any_instance.expects(:scoping).with(:>=, {:key => :value})
      @klass.type(:skills, :">=", :key => :value)
    end

  end

  describe "dynamic type scopes" do
    
    before do
      Tagtical::Tag.create(:value => "Plane")
      Tag::Skill.create(:value => "Kung Fu")
      Tag::FooCraft.create(:value => "Painting")
      NeedTag.create(:value => "chair") 
    end

    it "should accept :scope condition separately from the options" do
      Tagtical::Tag.skills(:current).should have_only_tag_values ["Kung Fu"]
      Tagtical::Tag.skills(:==).should have_only_tag_values ["Kung Fu"]
      Tagtical::Tag.crafts(:>).should have_only_tag_values ["Kung Fu", "Plane"]
    end

    context "when :scope => :current or the alias :==" do
      it "should retrieve current STI level tags" do
        Tagtical::Tag.skills.should have_only_tag_values ["Kung Fu", "Painting"]
        Tagtical::Tag.skills(:scope => :current).should have_only_tag_values ["Kung Fu"]
        Tagtical::Tag.skills(:scope => :==).should have_only_tag_values ["Kung Fu"]
      end
    end

    context "when :scope => :parent or the alias :>" do
      it "should retrieve parent STI level tags" do
        Tagtical::Tag.skills.should have_only_tag_values ["Kung Fu", "Painting"]
        Tagtical::Tag.crafts(:scope => :parents).should have_only_tag_values ["Kung Fu", "Plane"]
        Tagtical::Tag.crafts(:scope => :>).should have_only_tag_values ["Kung Fu", "Plane"]
        Tagtical::Tag.skills(:scope => :>).should have_only_tag_values ["Plane"]
      end 
    end

    context "when :scope => :childern or the alias :<" do
      it "should retrieve child STI level tags" do
        Tagtical::Tag.skills.should have_only_tag_values ["Kung Fu", "Painting"]
        Tagtical::Tag.skills(:scope => :children).should have_only_tag_values ["Painting"]
        Tagtical::Tag.skills(:scope => :<).should have_only_tag_values ["Painting"]
      end
    end

    context "when :scope => :\"><\"" do
      it "should retrieve parent and child STI level tags" do
        Tagtical::Tag.skills.should have_only_tag_values ["Kung Fu", "Painting"]
        Tagtical::Tag.skills(:scope => :"><").should have_only_tag_values ["Plane", "Painting"]
      end
    end

    context "when :scope => :>=" do
      it "should retrieve current and parent STI level tags" do
        Tagtical::Tag.skills.should have_only_tag_values ["Kung Fu", "Painting"]
        Tagtical::Tag.skills(:scope => :>=).should have_only_tag_values ["Kung Fu", "Plane"]
      end
    end

    context "when :scope => :<=" do
      it "should retrieve current and child STI level tags" do
        Tagtical::Tag.skills.should have_only_tag_values ["Kung Fu", "Painting"]
        Tagtical::Tag.skills(:scope => :<=).should have_only_tag_values ["Kung Fu", "Painting"]
      end
    end
  end

  describe ".define_scope_for_type" do
    before do
      @skill = Tag::Skill.new(:value => "baskeball")
      @craft = Tag::FooCraft.new(:value => "pottery")
    end

    it "should have a quester method" do
      @skill.tag?.should be_true
      @skill.skill?.should be_true
      @skill.craft?.should be_false
    end

    it "should have a quester method that considers inheritance" do
      @craft.tag?.should be_true
      @craft.skill?.should be_true
      @craft.craft?.should be_true
    end

  end

  it "should refresh @value on value setter" do
    @tag.value = "foo"
    @tag.value.should == "foo"
    @tag.value = "bar"
    @tag.value.should == "bar"
  end

  describe "#inspect" do

    it "should append relevance when provided" do
      pending("It's not trivial to do this in 3.2")
      @tag["relevance"] = "0.45"
      @tag.inspect.should == "#<Tagtical::Tag id: nil, value: \"train\", type: nil, relevance: 0.45>"
    end

  end

  describe "sort" do

    before do
      @tag1 = @klass.new(:value => "car").tap { |x| x.relevance = "2.5" }
      @tag2 = @klass.new(:value => "plane").tap { |x| x.relevance = "1.7" }
      @tag3 = @klass.new(:value => "bike").tap { |x| x.relevance = "1.1" }
      @tags = [@tag1, @tag2, @tag3]
    end

    it "should sort by relevance if all tags have them" do
      @tags.sort.map(&:value).should == ["bike", "plane", "car"]
    end

    it "should fallback gracefully when relevance not provided" do
      @tag3.relevance = nil
      @tags.sort.map(&:value).should == ["bike", "plane", "car"]
    end

    it "should sort by value when no relevances provided" do
      @tags.each { |t| t.relevance = nil }
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
      @taggable_model = TaggableModel
      @klass = @klass::Type
      @type = @klass.new("skill", @taggable_model)
    end
    subject { @type }

    its(:klass) { should == Tag::Skill }
    its(:scope_name) { should == :skills }

    describe ".find" do
      it "converts string into correct format" do
        {"ClassNames" => "class_name", "photo_tags" => "photo", :photo => "photo"}.each do |input, result|
          @klass.find(input, @taggable_model).should == result
        end
      end
    end

    describe ".[]" do
      specify { @klass[@type, @taggable_model].should equal @type }
      specify { @klass["foo", @taggable_model].should be_a @klass }
    end

    describe "#==" do
      {"foo" => false, "skill" => true, Tagtical::Tag::Type.new("skill", @taggable_class) => true}.each do |obj, result|
        specify { (subject==obj).should==result }
      end
    end

    describe "#convert_scope_options" do
      {:<=   => [:children, :current],
       :>=   => [:parents, :current],
       :"<>" => [:children, :parents],
       :==   => [:current],
       "=="  => [:current], # should work with strings as well.
       :">"  => [:parents],
       :"<"  => [:children]
      }.each do |operator, expected|
        it "should convert #{operator.inspect} to #{expected.inspect}" do
          subject.send(:convert_scope_options, operator).should have_same_elements(expected)
        end
      end
    end

    describe "#derive_class_candidates" do
      before(:all) do
        # use an inheriting tag model so we can test the building up the sti chain.
        @candidates = Tagtical::Tag::Type.new("skill", InheritingTaggableModel).send(:derive_class_candidates)
      end
      subject { @candidates }
      
      it do
        should == ["Tagtical::Tag::InheritingTaggableModel::Skill", "Tagtical::Tag::InheritingTaggableModel::SkillTag",
          "Tagtical::Tag::TaggableModel::SkillTag", "Tagtical::Tag::TaggableModel::Skill", "Tagtical::Tag::SkillTag",
          "Tagtical::Tag::Skill", "Tagtical::Tag::InheritingTaggableModelSkill", "Tag::InheritingTaggableModel::Skill",
          "Tagtical::Tag::InheritingTaggableModelSkillTag", "Tag::InheritingTaggableModel::SkillTag",
          "Tagtical::Tag::TaggableModelSkill", "Tag::TaggableModel::Skill", "Tagtical::Tag::TaggableModelSkillTag",
          "Tag::TaggableModel::SkillTag", "Tag::SkillTag", "Tag::Skill", "Tag::InheritingTaggableModelSkillTag",
          "InheritingTaggableModel::Skill", "InheritingTaggableModel::SkillTag", "Tag::InheritingTaggableModelSkill",
          "TaggableModel::Skill", "Tag::TaggableModelSkill", "TaggableModel::SkillTag", "Tag::TaggableModelSkillTag",
          "SkillTag", "Skill", "InheritingTaggableModelSkill", "InheritingTaggableModelSkillTag", "TaggableModelSkill", "TaggableModelSkillTag"]
      end

      it "should be favor deeper sti levels" do
        nesting_counts = @candidates.map { |x| x.split("::").size }
        nesting_counts.sort_by { |c| -c }.should == nesting_counts
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
      before { @type = @klass.new("tag", TaggableModel) }
      its(:klass) { should == Tagtical::Tag }
      its(:scope_name) { should == :tags }
    end

  end
end
