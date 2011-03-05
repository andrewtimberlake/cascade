require 'spec_helper'

class MyJob < Cascade::Job
end

module Cascade
  describe Job do
    let(:job) { MyJob.new(:my_data => [1,2,3]) }

    it "should be able to describe itself" do
      job.describe.should == 'MyJob'
    end
  end
end
