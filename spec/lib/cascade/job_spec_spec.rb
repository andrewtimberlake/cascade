require 'spec_helper'

module Cascade
  describe JobSpec do
    let(:job_spec) { MyJob.enqueue }
    context "#reset!" do
      before do
        job_spec.update_attributes(:failed_at => Time.now,
                                   :last_error => 'Test Error',
                                   :locked_at => Time.now,
                                   :locked_by => 'Test worker',
                                   :attempts => 1)
        job_spec.reset!
      end

      it "resets the failed_at attribute" do
        job_spec.failed_at.should be_nil
      end

      it "resets the last_error attribute" do
        job_spec.last_error.should be_nil
      end

      it "resets the locked_at attribute" do
        job_spec.locked_at.should be_nil
      end

      it "resets the locked_by attribute" do
        job_spec.locked_by.should be_nil
      end

      it "resets the attempts attribute" do
        job_spec.attempts.should eql(0)
      end
    end
  end
end
