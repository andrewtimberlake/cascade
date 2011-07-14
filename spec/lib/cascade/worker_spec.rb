require 'spec_helper'

module Cascade
  describe Worker do
    context "when running all jobs" do
      before do
        MyJob.enqueue
        ErrorJob.enqueue

        result = Worker.run

        @success = result[0]
        @failure = result[1]
      end

      it "runs all the jobs in the queue" do
        JobSpec.count.should == 1 #The failed job
      end

      it "indicates 1 success" do
        @success.should == 1
      end

      it "indicates 1 failure" do
        @failure.should == 1
      end
    end

    context "when the job raises an exception" do
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

    context "when the job fails" do
      let(:job_spec) { CatastrophicFailureJob.enqueue }

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

    context "when a job is set to re-run" do
      let(:job_spec) { RepeatableJob.enqueue }

      before do
        job_spec
        Worker.run
      end

      it "should remove the locks" do
        job_spec.reload
        job_spec.locked_by.should be_nil
        job_spec.locked_at.should be_nil
      end

      it "should save the re_run flag" do
        job_spec.reload
        job_spec.re_run.should be_true
      end
    end
  end
end
