# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{tagtical}
  s.version = "1.5.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Aryk Grosz"]
  s.date = %q{2011-12-22}
  s.description = %q{Tagtical allows you do create subclasses for Tag and add additional functionality in an STI fashion. For example. You could do Tag::Color.find_by_name('blue').to_rgb. It also supports storing weights or relevance on the taggings.}
  s.email = %q{aryk@mixbook.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    "CHANGELOG",
    "Gemfile",
    "Gemfile.lock",
    "MIT-LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "generators/tagtical_migration/tagtical_migration_generator.rb",
    "generators/tagtical_migration/templates/migration.rb",
    "lib/generators/tagtical/migration/migration_generator.rb",
    "lib/generators/tagtical/migration/templates/active_record/migration.rb",
    "lib/tagtical.rb",
    "lib/tagtical/acts_as_tagger.rb",
    "lib/tagtical/compatibility/Gemfile",
    "lib/tagtical/compatibility/active_record_backports.rb",
    "lib/tagtical/tag.rb",
    "lib/tagtical/tag_list.rb",
    "lib/tagtical/taggable.rb",
    "lib/tagtical/taggable/cache.rb",
    "lib/tagtical/taggable/collection.rb",
    "lib/tagtical/taggable/core.rb",
    "lib/tagtical/taggable/ownership.rb",
    "lib/tagtical/taggable/related.rb",
    "lib/tagtical/tagging.rb",
    "lib/tagtical/tags_helper.rb",
    "rails/init.rb",
    "spec/bm.rb",
    "spec/database.yml",
    "spec/database.yml.sample",
    "spec/models.rb",
    "spec/schema.rb",
    "spec/spec_helper.rb",
    "spec/tagtical/acts_as_tagger_spec.rb",
    "spec/tagtical/tag_list_spec.rb",
    "spec/tagtical/tag_spec.rb",
    "spec/tagtical/taggable_spec.rb",
    "spec/tagtical/tagger_spec.rb",
    "spec/tagtical/tagging_spec.rb",
    "spec/tagtical/tags_helper_spec.rb",
    "spec/tagtical/tagtical_spec.rb"
  ]
  s.homepage = %q{https://github.com/Mixbook/tagtical}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{Tagtical is a tagging plugin for Rails that provides weighting, contexts, and inheritance for tags.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rails>, ["<= 3.0.5"])
      s.add_runtime_dependency(%q<rspec>, [">= 0"])
      s.add_runtime_dependency(%q<sqlite3-ruby>, [">= 0"])
      s.add_runtime_dependency(%q<mysql>, [">= 0"])
      s.add_runtime_dependency(%q<jeweler>, [">= 0"])
      s.add_runtime_dependency(%q<rcov>, [">= 0"])
    else
      s.add_dependency(%q<rails>, ["<= 3.0.5"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<sqlite3-ruby>, [">= 0"])
      s.add_dependency(%q<mysql>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
      s.add_dependency(%q<rcov>, [">= 0"])
    end
  else
    s.add_dependency(%q<rails>, ["<= 3.0.5"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<sqlite3-ruby>, [">= 0"])
    s.add_dependency(%q<mysql>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
    s.add_dependency(%q<rcov>, [">= 0"])
  end
end

