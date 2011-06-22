begin
  # Rspec 1.3.0
  require 'spec/rake/spectask'

  desc 'Default: run specs'
  task :default => :spec
  Spec::Rake::SpecTask.new do |t|
    t.spec_files = FileList["spec/**/*_spec.rb"]
  end

  Spec::Rake::SpecTask.new('rcov') do |t|
    t.spec_files = FileList["spec/**/*_spec.rb"]
    t.rcov = true
    t.rcov_opts = ['--exclude', 'spec']
  end
  
rescue LoadError
  # Rspec 2.0
  require 'rspec/core/rake_task'

  desc 'Default: run specs'
  task :default => :spec  
  Rspec::Core::RakeTask.new do |t|
    t.pattern = "spec/**/*_spec.rb"
  end
  
  Rspec::Core::RakeTask.new('rcov') do |t|
    t.pattern = "spec/**/*_spec.rb"
    t.rcov = true
    t.rcov_opts = ['--exclude', 'spec']
  end

rescue LoadError
  puts "Rspec not available. Install it with: gem install rspec"  
end

namespace 'rails2.3' do
  task :spec do
    gemfile = File.join(File.dirname(__FILE__), 'lib', 'tagtical', 'compatibility', 'Gemfile')
    ENV['BUNDLE_GEMFILE'] = gemfile
    Rake::Task['spec'].invoke    
  end
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "tagtical"
    gemspec.summary = "Tagtical is a tagging plugin for Rails that provides weighting, contexts, and inheritance for tags."
    gemspec.description = "Tagtical allows you do create subclasses for Tag and add additional functionality in an STI fashion. For example. You could do Tag::Color.find_by_name('blue').to_rgb. It also supports storing weights or relevance on the taggings."
    gemspec.email = "aryk@mixbook.com"
    gemspec.homepage = "https://github.com/Mixbook/tagtical"
    gemspec.authors = ["Aryk Grosz"]
    gemspec.files =  FileList["[A-Z]*", "{generators,lib,spec,rails}/**/*"] - FileList["**/*.log"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end