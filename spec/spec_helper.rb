$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'cascade'

RSpec.configure do |config|
end

def fixture(path)
  File.join(File.dirname(__FILE__), 'fixtures', "#{path}")
end

class MyJob < Cascade::Job
end
