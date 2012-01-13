$LOAD_PATH << "." unless $LOAD_PATH.include?(".")
require 'logger'

begin
  require "rubygems"
  require "bundler"

  if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.5")
    raise RuntimeError, "Your bundler version is too old." +
     "Run `gem install bundler` to upgrade."
  end

  # Set up load paths for all bundled gems
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
    "Did you run \`bundler install\`?"
end

Bundler.require(:test, :default)
require File.expand_path('../../lib/tagtical', __FILE__)

RSpec.configure do |config|
  config.mock_with :mocha
end

RSpec::Matchers.define :have_only_tag_values do |expected|
  match do |actual|
    actual = actual.tags if actual.class.respond_to?(:taggable?) && actual.class.taggable?
    actual.map(&:value).should have_same_elements(expected)
  end
end
RSpec::Matchers.define :have_same_elements do |expected|
  match do |actual|
    actual.sort == expected.sort
  end
end

# Rspec when we want to work with possible values.
def when_possible_values_specified(options={}, &block)
  options = {:klass => Tagtical::Tag, :values => %w{knife fork spoon}}.update(options)
  context "when possible_values specified" do
    before { options[:klass].possible_values = options[:values] }
    after  { options[:klass].possible_values = nil}
    instance_exec(&block)
  end
end

unless [].respond_to?(:freq)
  class Array
    def freq
      k=Hash.new(0)
      each {|e| k[e]+=1}
      k
    end
  end
end

ENV['DB'] ||= 'sqlite3'

database_yml = File.expand_path('../database.yml', __FILE__)
if File.exists?(database_yml)
  active_record_configuration = YAML.load_file(database_yml)[ENV['DB']]
  
  ActiveRecord::Base.establish_connection(active_record_configuration)
  ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
  
  ActiveRecord::Base.silence do
    ActiveRecord::Migration.verbose = false
    
    require(File.dirname(__FILE__) + '/schema.rb')
    require(File.dirname(__FILE__) + '/models.rb')
  end  
  
else
  raise "Please create #{database_yml} first to configure your database. Take a look at: #{database_yml}.sample"
end

def clean_database!
  models = [Tagtical::Tag, Tagtical::Tagging, TaggableModel, OtherTaggableModel, InheritingTaggableModel,
            AlteredInheritingTaggableModel, TaggableUser, UntaggableModel]
  models.each do |model|
    ActiveRecord::Base.connection.execute "DELETE FROM #{model.table_name}"
  end
end

clean_database!

module QueryAnalyzer
  extend self
  attr_accessor :enabled, :options
  self.enabled = false
  self.options = {}

  IGNORE_SQL_REGEXP = /^explain/i # ignore SQL explain

  def start(options=nil)
    options = {:match => options} if options.is_a?(Regexp)
    if block_given?
      begin
        (old_options, @options = @options, options) if options
        old_enabled, @enabled = @enabled, true
        yield
      ensure
        @enabled = old_enabled
        @options = old_options if options
      end
    else
      @options = options if options
      @enabled = true
    end
  end

  # Always disable it in production environment
  def enabled?(sql=nil)
    !Rails.env.production? && (@enabled && (!sql || match_sql?(sql)))
  end

  def match_sql?(sql)
    sql !~ IGNORE_SQL_REGEXP && (!options[:match] || options[:match]===sql)
  end

  def stop
    options.clear
    @enabled = false
  end

  #  class Results < Array
  #
  #    def qa_columnized
  #      sized = {}
  #      self.each do |row|
  #        row.values.each_with_index do |value, i|
  #          sized[i] = [sized[i].to_i, row.keys[i].length, value.to_s.length].max
  #        end
  #      end
  #
  #      table = []
  #      table << qa_columnized_row(self.first.keys, sized)
  #      table << '-' * table.first.length
  #      self.each { |row| table << qa_columnized_row(row.values, sized) }
  #      table.join("\n   ") # Spaces added to work with format_log_entry
  #    end
  #
  #    private
  #
  #    def qa_columnized_row(fields, sized)
  #      row = []
  #      fields.each_with_index do |f, i|
  #        row << sprintf("%0-#{sized[i]}s", f.to_s)
  #      end
  #      row.join(' | ')
  #    end
  #
  #  end # Results
end

module ActiveRecord
  module ConnectionAdapters
    class SQLiteAdapter < AbstractAdapter
      private

      def execute_with_analyzer(sql, name = nil)
        if QueryAnalyzer.enabled?(sql)
          display = "\nQUERY ANALYZER: \n#{sql}"
          puts [display, nil, caller.map { |str| str.insert(0, "   -> ")}]
          @logger.debug(display) if @logger && @logger.debug?
        end
        execute_without_analyzer(sql, name)
      end
      # Always disable this in production
      alias_method_chain :execute, :analyzer if defined?(Rails) && !Rails.env.production?

    end
  end
end
