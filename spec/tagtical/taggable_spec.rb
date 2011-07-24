require File.expand_path('../../spec_helper', __FILE__)
describe Tagtical::Taggable do
  before do
    clean_database!
    @taggable = TaggableModel.new(:name => "Bob Jones")
    @taggables = [@taggable, TaggableModel.new(:name => "John Doe")]
  end
  subject { @taggable }

  it "should have tag types" do
    TaggableModel.tag_types.should include("tag", "language", "skill", "craft", "need", "offering")
    @taggable.tag_types.should == TaggableModel.tag_types
  end

  it "should have tag_counts_on" do
    TaggableModel.tag_counts_on(:tags).all.should be_empty

    @taggable.tag_list = ["awesome", "epic"]
    @taggable.save

    TaggableModel.tag_counts_on(:tags).length.should == 2
    @taggable.tag_counts_on(:tags).length.should == 2
  end

  it "should be able to create tags" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.tag_list_on(:skills).should be_an_instance_of(Tagtical::TagList)

    lambda { @taggable.save }.should change(Tagtical::Tag, :count).by(3)

    @taggable.reload
    @taggable.skill_list.sort.should == %w(ruby rails css).sort
    @taggable.tag_list.sort.should == %w(ruby rails css).sort
  end

  it "should differentiate between contexts" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.tag_list = "ruby, bob, charlie"
    @taggable.save
    @taggable.reload
    @taggable.skill_list.should include("ruby")
    @taggable.skill_list.should_not include("bob")
  end

  it "should be able to remove tags through list alone" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.save
    @taggable.reload
    @taggable.should have(3).skills
    @taggable.skill_list = "ruby, rails"
    @taggable.save
    @taggable.reload
    @taggable.should have(2).skills
  end

  describe "Tag Type Scopes" do
    before do
      @taggable.update_attributes!(:tag_list => "tree, train", :skill_list => "basketball", :craft_list => "pottery")
      @taggable.reload
    end

    describe "inherited tags scope optimizations" do
      before do
        @taggable.tags.to_a # load the target
      end

      it "should not access the database when top level tags are already loaded" do
        ActiveRecord::Base.connection.expects(:execute).never
        @taggable.skills.to_a
        @taggable.skills.should have_only_tag_values %w{basketball pottery}
        @taggable.crafts(:current).should have_only_tag_values %w{pottery}
        @taggable.skills(:current).should have_only_tag_values %w{basketball}
        @taggable.skills(:children).should have_only_tag_values %w{pottery}
        @taggable.tags.should have_only_tag_values %w{train tree basketball pottery}
      end

      it "should select the correct tags" do
        @taggable.skills.each { |tag| tag.should be_skill }
        @taggable.crafts.each { |tag| tag.should be_craft }
      end

    end
  end

  when_possible_values_specified(:values => %w{Knitting Ruby Pottery}) do
    
    before do
      @taggable.craft_list = "knitting, ruby"
      @taggable.save!
      @taggable.reload
    end

    it { should have_only_tag_values %w{Knitting Ruby} }

    it "should save only one tag with a value from the possible_values list" do
      @taggable.craft_list.add("ruby", "pottery")
      @taggable.save!
      @taggable.reload
      @taggable.should have_only_tag_values %w{Knitting Ruby Pottery}
    end

  end

  describe "#cascade_set_tag_list!" do
    when_possible_values_specified(:values => %w{Knitting Ruby Pottery}, :klass => Tag::Skill) do
      before do
        @taggable.update_attributes!(:tag_list => "tree, train", :skill_list => "basketball", :craft_list => "pottery")
        @taggable.reload
      end

      context "when :cascade => true" do
        before do
          @taggable.set_tag_list(["ruby : 7 ", "plain  "], :cascade => true)
          @taggable.save!
          @taggable.reload
        end

        specify do
          @taggable.tag_list.should have_same_elements %w{Ruby plain}
        end

        it "should set value on skill even if different case" do
          @taggable.skills.should have_only_tag_values %w{Ruby}
        end

        it "should keep the tag's relevance" do
          @taggable.skills[0].relevance.should == 7
        end

        it "should remove all elements from craft" do
          @taggable.crafts.should be_empty
        end

      end
      context "when :cascade only on :craft" do
        before do
          @taggable.set_tag_list(["ruby", "plain"], :cascade => true, :types => :craft)
          @taggable.save!
          @taggable.reload
        end

        specify do
          @taggable.tag_list.should have_same_elements %w{Ruby plain}
        end

        it "should not have any tags on skills directly" do
          @taggable.skills(:current).should be_empty
        end

        it "should have tags on crafts" do
          @taggable.craft_list.should have_same_elements %w{Ruby}
        end

      end
      context "Adding tags with Exclusion" do

        before do
          @taggable.set_tag_list "Ruby, plain", :cascade => true, :except => :skill
          @taggable.save!
          @taggable.reload
        end

        it "should not change the tags in skill" do
          @taggable.skill_list.should have_same_elements ["basketball", "pottery"]
        end

        it "should have set the values at the tag level" do
          @taggable.tag_list(:current).should have_same_elements ["Ruby", "plain"]
        end

      end
      context "Getting tag_list with :except" do

        before do
          @taggable.set_tag_list "Ruby, plain", :cascade => true
          @taggable.save!
          @taggable.reload
        end

        it "should exclude all defined types" do
          @taggable.tag_list(:except => :skill).should have(1).item
        end

      end

    end
  end

  describe "Eager Loading Tags" do
    before do
      @taggables[0].update_attributes!(:craft_list => "foo:0.9, bar, car")
      @taggables[1].update_attributes!(:craft_list => "foo:0.3")

      @taggables = TaggableModel.all(:include => :tags)
    end

    it "should leverage eager loaded tags for tag_list" do
      ActiveRecord::Base.connection.expects(:execute).never
      @taggables[0].tag_list
      @taggables[0].craft_list
      @taggables[0].skill_list
    end

    it "should populate relevance on tags and preserve different relevances" do
      ActiveRecord::Base.connection.expects(:execute).never
      @taggables[0].tags.detect { |t| t.value=="foo" }.relevance.should==0.9
      @taggables[1].tags.detect { |t| t.value=="foo" }.relevance.should==0.3
    end
    
  end

  describe "tag_list scoping behavior" do
    before do
      @taggables[0].tag_list = "bob"
      @taggables[1].tag_list = "charlie"
      @taggables[0].skill_list = "ruby"
      @taggables[1].skill_list = "css"
      @taggables[0].craft_list = "knitting"
      @taggables[1].craft_list = "pottery"
      @taggables.each(&:save!)
      @taggables.each(&:reload)
    end

    it "should empty out inheriting tags" do
      @taggables[0].tag_list = []
      @taggables[0].save!
      @taggables[0].reload

      @taggables[0].crafts.should be_empty
    end

    it "should not empty out 'tag' type when :current scope" do
      @taggables[0].set_tag_list([], :current)
      @taggables[0].save!
      @taggables[0].reload

      @taggables[0].tags.should_not be_empty
      @taggables[0].tags(:current).should be_empty
      @taggables[0].skills.should_not be_empty
      @taggables[0].crafts.should_not be_empty
    end

    it "should be able to query tags" do
      @taggables[0].tags(:scope => :current).should have_only_tag_values %w{bob}
      @taggables[0].tags(:==).should have_only_tag_values %w{bob}
      @taggables[0].tags.should have_only_tag_values %w{bob knitting ruby}
      @taggables[0].tags(:scope => :children).should have_only_tag_values %w{knitting ruby}
      @taggables[0].tags(:scope => :<).should have_only_tag_values %w{knitting ruby}
      @taggables[1].crafts(:parents).should have_only_tag_values %w{charlie css}
      @taggables[1].crafts(:scope => :>).should have_only_tag_values %w{charlie css}

      @taggables[1].crafts(:scope => [:parents, :current]).should have_only_tag_values %w{charlie css pottery}
      @taggables[1].crafts(:scope => :>=).should have_only_tag_values %w{charlie css pottery}
      @taggables[1].skills(:scope => [:parents, :children]).should have_only_tag_values %w{charlie pottery}
      @taggables[1].skills(:scope => :"><").should have_only_tag_values %w{charlie pottery}
    end

    it "should be able to select taggables by subset of tags using ActiveRelation methods" do
      TaggableModel.with_tags("bob").should == [@taggables[0]]
      TaggableModel.with_skills("ruby").should == [@taggables[0]]
      TaggableModel.with_tags("rUBy").should == [@taggables[0]]
      TaggableModel.with_tags("ruby", :scope => :current).should == []
      TaggableModel.with_tags("ruby", :scope => :==).should == []
      TaggableModel.with_skills("knitting").should == [@taggables[0]]
      TaggableModel.with_skills("KNITTING", :scope => :current).should == []
      TaggableModel.with_skills("KNITTING", :scope => :==).should == []
      TaggableModel.with_skills("knitting", :scope => :parents).should == []
      TaggableModel.with_skills("knitting", :scope => :>).should == []
      TaggableModel.with_tags("bob", :scope => :current).should == [@taggables[0]]
      TaggableModel.with_tags("bob", :scope => :==).should == [@taggables[0]]
      TaggableModel.with_skills("bob", :scope => :parents).should == [@taggables[0]]
      TaggableModel.with_skills("bob", :scope => :>).should == [@taggables[0]]
      TaggableModel.with_crafts("knitting").should == [@taggables[0]]
    end
  end

  it "should be able to find by tag" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.save

    TaggableModel.tagged_with("ruby").first.should == @taggable
  end

  it "should be able to find by tag with context" do
    @taggable.skill_list = "ruby, rails, css"
    @taggable.tag_list = "bob, charlie"
    @taggable.save

    TaggableModel.tagged_with("ruby").first.should == @taggable
    TaggableModel.tagged_with("ruby, css").first.should == @taggable
    TaggableModel.tagged_with("bob", :on => :skills).first.should_not == @taggable
    TaggableModel.tagged_with("bob", :on => :tags).first.should == @taggable
  end

  it "should be able to search by tag type" do
    TaggableModel.create!(:name => "Ted", :skill_list => "ruby")
    TaggableModel.create!(:name => "Tom", :skill_list => "ruby, rails, css")
    TaggableModel.create!(:name => "Fiona", :skill_list => "html, ruby, rails, css")

    TaggableModel.tagged_with("ruby", :on => :skills).sort_by(&:id).should == TaggableModel.with_skills("ruby").sort_by(&:id)
    TaggableModel.tagged_with(["ruby", "rails", "css"], :on => :skills).sort_by(&:id).should == TaggableModel.with_skills("ruby", "rails", "css").sort_by(&:id)
    TaggableModel.with_skills("ruby", "rails").should have(2).items
  end

  it "should not duplicate tags" do
    @taggable = TaggableModel.create!(:name => "Gary", :skill_list => ["Ruby", "ruby", "RUBY", "rails"])

    @taggable.skill_list.should have(2).item
  end

  describe "Tag Scope" do
    it "should proxy argument from tag scope to tagged_with" do
      { ["ruby", "rails", {:any => true}] => [['ruby', 'rails'], {:any => true, :on => :skill}],
        ["ruby", "rails"] => [['ruby', 'rails'], {:on => :skill}],
        [] => [[], {:on => :skill}],
        [["ruby", "rails"]] => [['ruby', 'rails'], {:on => :skill}]
      }.each do |input, output|
        TaggableModel.expects(:tagged_with).with(*output)
        TaggableModel.with_skills(*input)
      end
    end
  end

  it "should not care about case" do
    bob = TaggableModel.create!(:name => "Bob", :tag_list => "ruby")
    frank = TaggableModel.create!(:name => "Frank", :tag_list => "Ruby")

    Tagtical::Tag.find(:all).size.should == 1
    TaggableModel.tagged_with("ruby").to_a.should == TaggableModel.tagged_with("Ruby").to_a
  end

  it "should be able to get tag counts on model as a whole" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
    charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby")
    TaggableModel.tag_counts.all.should_not be_empty
    TaggableModel.skill_counts.all.should_not be_empty
  end

  it "should be able to get all tag counts on model as whole" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
    charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby")

    TaggableModel.all_tag_counts.all.should_not be_empty
    TaggableModel.all_tag_counts(:order => 'tags.id').map { |tag| [tag.class, tag.value, tag.count] }.should == [
      [Tagtical::Tag, "ruby", 2],
      [Tagtical::Tag, "rails", 2],
      [Tagtical::Tag, "css", 1],
      [Tag::Skill, "ruby", 1] ]
  end

  if ActiveRecord::VERSION::MAJOR >= 3
    it "should not return read-only records" do
      TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
      TaggableModel.tagged_with("ruby").first.should_not be_readonly
    end
  else
    it "should not return read-only records" do
      # apparantly, there is no way to set readonly to false in a scope if joins are made
    end

    it "should be possible to return writable records" do
      TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
      TaggableModel.tagged_with("ruby").first(:readonly => false).should_not be_readonly
    end
  end

  context "with inheriting tags classes" do
    before do
      @taggable.tag_list = "bob"
      @taggable.skill_list = "ruby"
      @taggable.craft_list = "knitting"
      @taggable.save!
      @taggable.reload
    end

    context "with tag_list options" do
      it "should ignore tag subclasses with :scope => :current" do
        @taggable.set_tag_list([], :scope => :current)
        @taggable.save!
        @taggable.reload

        @taggable.tags(:current).should be_empty
        @taggable.tags.should_not be_empty
        @taggable.skills.should_not be_empty
        @taggable.crafts.should_not be_empty
      end
    end

    it "should have tag_lists with inheriting tags" do
      @taggable.tag_list.should have_same_elements %w{bob ruby knitting}
      @taggable.skill_list.should have_same_elements %w{ruby knitting}
    end

    it "should nullify out inheriting tags on tag_list setter" do
      @taggable.tag_list = []
      @taggable.save!
      @taggable.reload

      @taggable.tags.should be_empty
      @taggable.skills.should be_empty
      @taggable.crafts.should be_empty
    end
    
    it "should nullify out inheriting tags on skill_list setter but keep the tags in the super class" do
      @taggable.skill_list = []
      @taggable.save!
      @taggable.reload

      @taggable.tags.should have_only_tag_values %w{bob}
      @taggable.skills.should be_empty
      @taggable.crafts.should be_empty
    end

    it "should not create tags on parent if children have the value" do
      Tagtical::Tag.delete_all
      lambda {
        @taggable.skill_list = "pottery"
        @taggable.save!
        @taggable.reload
        @taggable.craft_list = "pottery"
        @taggable.save!
      }.should change(Tagtical::Tagging, :count).by(1)

      @taggable.reload
      @taggable.skills.should have(1).item
      @taggable.skills.first.should be_an_instance_of Tag::FooCraft
    end

  end

  context "with multiple taggable models" do

    before do
      @bob = TaggableModel.create(:name => "Bob", :tag_list => "ruby, rails, css")
      @frank = TaggableModel.create(:name => "Frank", :tag_list => "ruby, rails")
      @charlie = TaggableModel.create(:name => "Charlie", :skill_list => "ruby, java")
    end

    RSpec::Matchers.define :have_tags_counts_of do |expected|
      def breakdown(tags)
        tags.map { |tag| [tag.class, tag.value, tag.count] }
      end
      match do |actual|
        breakdown(actual) == expected
      end
      failure_message_for_should do |actual|
        "expected #{breakdown(actual)} to have the breakdown #{expected}"
      end
    end

    it "should be able to get scoped tag counts" do
      TaggableModel.tagged_with("ruby").tag_counts(:order => 'tags.id').should have_tags_counts_of [
        [Tagtical::Tag, "ruby", 2],
        [Tagtical::Tag, "rails", 2],
        [Tagtical::Tag, "css", 1],
        [Tag::Skill, "ruby", 1],
        [Tag::Skill, "java", 1] ]
      TaggableModel.tagged_with("ruby").skill_counts.first.count.should == 1 # ruby
    end

    it "should be able to get all scoped tag counts" do
      TaggableModel.tagged_with("ruby").all_tag_counts(:order => 'tags.id').should have_tags_counts_of [
        [Tagtical::Tag, "ruby", 2],
        [Tagtical::Tag, "rails", 2],
        [Tagtical::Tag, "css", 1],
        [Tag::Skill, "ruby", 1],
        [Tag::Skill, "java", 1] ]
    end

    it 'should only return tag counts for the available scope' do
      TaggableModel.tagged_with('rails').all_tag_counts.should have_tags_counts_of [
        [Tagtical::Tag, "ruby", 2],
        [Tagtical::Tag, "rails", 2],
        [Tagtical::Tag, "css", 1]]
      TaggableModel.tagged_with('rails').all_tag_counts.any? { |tag| tag.value == 'java' }.should be_false

      # Test specific join syntaxes:
      @frank.untaggable_models.create!
      TaggableModel.tagged_with('rails').scoped(:joins => :untaggable_models).all_tag_counts.should have(2).items
      TaggableModel.tagged_with('rails').scoped(:joins => {:untaggable_models => :taggable_model }).all_tag_counts.should have(2).items
      TaggableModel.tagged_with('rails').scoped(:joins => [:untaggable_models]).all_tag_counts.should have(2).items
    end
  end

  it "should be able to find tagged with quotation marks" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "fitter, happier, more productive, 'I love the ,comma,'")
    TaggableModel.tagged_with("'I love the ,comma,'").should include(bob)
  end

  it "should be able to find tagged with invalid tags" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "fitter, happier, more productive")
    TaggableModel.tagged_with("sad, happier").should_not include(bob)
  end

  context "with multiple tag lists per taggable model" do
    before do
      @bob = TaggableModel.create(:name => "Bob", :tag_list => "fitter, happier, more productive", :skill_list => "ruby, rails, css")
      @frank = TaggableModel.create(:name => "Frank", :tag_list => "weaker, depressed, inefficient", :skill_list => "ruby, rails, css")
      @steve = TaggableModel.create(:name => 'Steve', :tag_list => 'fitter, happier, more productive', :skill_list => 'c++, java, ruby')
    end

    it "should be able to find tagged" do
      TaggableModel.tagged_with("ruby", :order => 'taggable_models.name').to_a.should == [@bob, @frank, @steve]
      TaggableModel.tagged_with("ruby, rails", :order => 'taggable_models.name').to_a.should == [@bob, @frank]
      TaggableModel.tagged_with(["ruby", "rails"], :order => 'taggable_models.name').to_a.should == [@bob, @frank]
    end

    it "should be able to find tagged with any tag" do
      TaggableModel.tagged_with(["ruby", "java"], :order => 'taggable_models.name', :any => true).to_a.should == [@bob, @frank, @steve]
      TaggableModel.tagged_with(["c++", "fitter"], :order => 'taggable_models.name', :any => true).to_a.should == [@bob, @steve]
      TaggableModel.tagged_with(["fitter", "css"], :order => 'taggable_models.name', :any => true, :on => :skills).to_a.should == [@bob, @frank]
    end

    it "should be able to use named scopes to chain tag finds" do
      # Let's only find those productive Rails developers
      TaggableModel.tagged_with('rails', :on => :skills, :order => 'taggable_models.name').to_a.should == [@bob, @frank]
      TaggableModel.tagged_with('happier', :on => :tags, :order => 'taggable_models.name').to_a.should == [@bob, @steve]
      TaggableModel.tagged_with('rails', :on => :skills).tagged_with('happier', :on => :tags).to_a.should == [@bob]
      TaggableModel.tagged_with('rails').tagged_with('happier', :on => :tags).to_a.should == [@bob]
    end
  end

  it "should be able to find tagged with only the matching tags" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "lazy, happier")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "fitter, happier, inefficient")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => "fitter, happier")
    TaggableModel.tagged_with("fitter, happier", :match_all => true).to_a.should == [steve]
  end

  it "should be able to find tagged with some excluded tags" do
    bob = TaggableModel.create(:name => "Bob", :tag_list => "happier, lazy")
    frank = TaggableModel.create(:name => "Frank", :tag_list => "happier")
    steve = TaggableModel.create(:name => 'Steve', :tag_list => "happier")

    TaggableModel.tagged_with("lazy", :exclude => true).to_a.should == [frank, steve]
  end

  it "should not create duplicate taggings" do
    bob = TaggableModel.create(:name => "Bob")
    lambda {
      bob.tag_list << "happier"
      bob.tag_list << "happier"
      bob.save
    }.should change(Tagtical::Tagging, :count).by(1)
  end

  describe "Associations" do
    before(:each) do
      @taggable = TaggableModel.create(:tag_list => "awesome, epic", :skill_list => "basketball, hiking, boxing")
    end

    it "should not remove tags when creating associated objects" do
      @taggable.untaggable_models.create!
      @taggable.reload
      @taggable.tag_list.should have(5).items
    end

    its "tag_list methods should accept scope arguments" do
      @taggable.tag_list(:current).should have(2).items
      @taggable.skill_list(:parents).should have(2).items
      @taggable.skill_list(:current).should have(3).items
      @taggable.tag_list(:current, :children).should have(5).items
    end

  end

  describe "grouped_column_names_for method" do
    it "should return all column names joined for Tag GROUP clause" do
      @taggable.grouped_column_names_for(Tagtical::Tag).should == "tags.id, tags.value, tags.type"
    end

    it "should return all column names joined for TaggableModel GROUP clause" do
      @taggable.grouped_column_names_for(TaggableModel).should == "taggable_models.id, taggable_models.name, taggable_models.type"
    end
  end

  describe "Single Table Inheritance for tags" do
    before do
      @taggable = TaggableModel.new(:name => "taggable")
    end

  end

  describe "Single Table Inheritance" do
    before do
      @taggable = TaggableModel.new(:name => "taggable")
      @inherited_same = InheritingTaggableModel.new(:name => "inherited same")
      @inherited_different = AlteredInheritingTaggableModel.new(:name => "inherited different")
    end

    it "should be able to save tags for inherited models" do
      @inherited_same.tag_list = "bob, kelso"
      @inherited_same.save
      InheritingTaggableModel.tagged_with("bob").first.should == @inherited_same
    end

    it "should find STI tagged models on the superclass" do
      @inherited_same.tag_list = "bob, kelso"
      @inherited_same.save
      TaggableModel.tagged_with("bob").first.should == @inherited_same
    end

    it "should be able to add on contexts only to some subclasses" do
      @inherited_different.part_list = "fork, spoon"
      @inherited_different.save
      AlteredInheritingTaggableModel.tagged_with("fork", :on => :parts).first.should == @inherited_different
    end

    it "should have different tag_counts_on for inherited models" do
      @inherited_same.tag_list = "bob, kelso"
      @inherited_same.save!
      @inherited_different.tag_list = "fork, spoon"
      @inherited_different.save!

      InheritingTaggableModel.tag_counts_on(:tags, :order => 'tags.id').map(&:value).should == %w(bob kelso)
      AlteredInheritingTaggableModel.tag_counts_on(:tags, :order => 'tags.id').map(&:value).should == %w(fork spoon)
      TaggableModel.tag_counts_on(:tags, :order => 'tags.id').map(&:value).should == %w(bob kelso fork spoon)
    end

    it 'should store same tag without validation conflict' do
      @taggable.tag_list = 'one'
      @taggable.save!

      @inherited_same.tag_list = 'one'
      @inherited_same.save!

      @inherited_same.update_attributes! :name => 'foo'
    end
  end

  describe "#owner_tags_on" do
    before do
      @user = TaggableUser.create!
      @user1 = TaggableUser.create!
      @model = TaggableModel.create!(:name => "Bob", :tag_list => "fitter, happier, more productive")
      @user.tag(@model, :with => "martial arts", :on => :skills)
      @user1.tag(@model, :with => "pottery", :on => :crafts)
      @user1.tag(@model, :with => ["spoon", "pottery"], :on => :tags)
    end

    it "should ignore different contexts" do
      @model.owner_tags_on(@user, :languages).should be_empty
    end

    it "should return for only the specified context" do
      @model.owner_tags_on(@user, :skills).should have(1).items

      @model.owner_tags_on(@user, :tags).should have(1).items
      @model.owner_tags_on(@user1, :tags).should have(2).items
    end

    it "should preserve the tag type even though we tag on :tags" do
      @model.tags.find_by_value("pottery").should be_an_instance_of(Tag::FooCraft)
    end

    it "should support STI" do
      tag = @model.crafts.find_by_value("pottery")
      @model.owner_tags_on(@user1, :crafts).should == [tag]
      @model.owner_tags_on(@user1, :skills).should == [tag]
      @model.owner_tags_on(@user1, :tags).should include(tag)

    end
  end


  it "should be able to create tags through the tag list directly" do
    @taggable.tag_list_on(:skills).add("hello")
    @taggable.tag_list_cache_on(:skills).should_not be_empty
    @taggable.tag_list_on(:skills).should == ["hello"]

    @taggable.save
    @taggable.save_tags

    @taggable.reload
    @taggable.tag_list_on(:skills).should == ["hello"]
  end

    #it "should be able to set a custom tag context list" do
  #  bob = TaggableModel.create(:name => "Bob")
  #  bob.set_tag_list_on(:rotors, "spinning, jumping")
  #  bob.tag_list_on(:rotors).should == ["spinning","jumping"]
  #  bob.save
  #  bob.reload
  #  bob.tags_on(:rotors).should_not be_empty
  #end

  #it "should be able to find tagged on a custom tag context" do
  #  bob = TaggableModel.create(:name => "Bob")
  #  bob.set_tag_list_on(:rotors, "spinning, jumping")
  #  bob.tag_list_on(:rotors).should == ["spinning","jumping"]
  #  bob.save
  #
  #  TaggableModel.tagged_with("spinning", :on => :rotors).to_a.should == [bob]
  #end

end
