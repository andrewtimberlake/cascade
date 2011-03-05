require 'spec_helper'

class TestJob < Cascade::Job
  %w(before_queue before_run success error after_run).each do |callback|
    send(callback) do |job_spec|
      history << callback.to_sym
    end
  end

  def history
    @history ||= []
  end
end

module Cascade
  describe "Job::Callbacks" do
    it "should run the before_queue callback before the job is added to the queue" do
      job = TestJob.new
      Job.enqueue(job)
      job.history.should == [:before_queue]
    end
  end
end
