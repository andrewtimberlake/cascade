require 'spec_helper'

module Cascade
  describe Worker do
    it "should run all the jobs in the queue" do
      MyJob.enqueue(1, 2, :test => true)
      Worker.run

      JobSpec.count.should == 0
    end

    context "when the job fails" do
      let(:job_spec) { ErrorJob.enqueue }

      before do
        job_spec
        Worker.run
      end

      it "should set the last error if a job fails" do
        job_spec.reload
        job_spec.last_error.should_not be_nil
      end

      it "should set failed_at a job fails" do
        job_spec.reload
        job_spec.failed_at.should_not be_nil
      end
    end
  end
end
