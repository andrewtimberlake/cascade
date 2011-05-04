require 'spec_helper'

module Cascade
  describe Job do
    let(:job) { MyJob.new() }

    it "should be able to describe itself" do
      job.describe.should == 'MyJob'
    end
  end
end
