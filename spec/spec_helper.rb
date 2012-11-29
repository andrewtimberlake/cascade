require 'rubygems'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'mongo_mapper'
require 'timecop'
require 'cascade'

RSpec.configure do |config|
  MongoMapper.connection = Mongo::Connection.new
  MongoMapper.database = 'cascade_test'

  #Erase the entire database after each test
  config.after(:each) do
    MongoMapper.database.collections.each do |collection|
      collection.remove
    end
  end
end

def fixture(path)
  File.join(File.dirname(__FILE__), 'fixtures', "#{path}")
end

class MyJob
  include Cascade::Job

  def initialize(*args)
  end
end

class ErrorJob
  include Cascade::Job

  def run
    raise
  end
end

class ExceptionJob
  include Cascade::Job

  def run
    raise Exception
  end
end

class CatastrophicFailureJob
  include Cascade::Job

  def run
    exit!
  end
end

class RepeatableJob
  include Cascade::Job

  on_success do |job_spec|
    job_spec.re_run = true
  end
end

class ExitableJob
  include Cascade::Job

  def run
    count = 0
    loop do
      sleep 0.1
      raise Cascade::ReRun if $exit
      count += 1
      raise 'This should have exited by now' if count > 1000
    end
  end
end
