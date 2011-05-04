require 'spec_helper'

module Cascade
  describe Queue do
    it "should run all the jobs in the queue" do
      MyJob.enqueue(1, 2, :test => true)
      Queue.run

      JobSpec.count.should == 0
    end
  end
end
