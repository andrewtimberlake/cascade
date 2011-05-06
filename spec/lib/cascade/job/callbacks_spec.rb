require 'spec_helper'

class TestJob
  include Cascade::Job

  def initialize(raise_error = false)
    @raise_error = raise_error
  end

  %w(before_queue before_run on_success on_error after_run).each do |callback|
    send(callback) do |job_spec|
      history << callback.to_sym
    end
  end

  def history
    @history ||= []
  end

  def run
    raise if @raise_error
  end
end

module Cascade
  describe "Job::Callbacks" do
    it "should run the before_queue callback before the job is added to the queue" do
      job_spec = TestJob.enqueue
      job = job_spec.job
      job.history.should == [:before_queue]
    end

    it "should run before_queue, before_run, on_success and after_run callbacks on a successful job run" do
      job_spec = TestJob.enqueue
      job = job_spec.job
      Worker.run_job(job_spec, job)

      job.history.should == [:before_queue, :before_run, :on_success, :after_run]
    end

    it "should run before_queue, before_run, on_error and after_run callbacks on a successful job run" do
      job_spec = TestJob.enqueue(true)
      job = job_spec.job
      Worker.run_job(job_spec, job)

      job.history.should == [:before_queue, :before_run, :on_error, :after_run]
    end
  end
end
