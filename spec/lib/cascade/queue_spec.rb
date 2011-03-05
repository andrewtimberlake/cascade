require 'spec_helper'

module Cascade
  describe Queue do
    it "should run all the jobs in the queue" do
      Job.enqueue(MyJob.new(:my_data => [1,2,3]))
      Queue.job_specs.size.should == 1
      Queue.run
      Queue.job_specs.size.should == 0
    end
  end
end
