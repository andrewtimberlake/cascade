require 'spec_helper'

class TestJob
  include Cascade::Job

  after_fork do |job_spec|
    job_spec['after_fork'] = true
  end

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

class SubClassJob < TestJob

end

class SubSubClassJob < SubClassJob

end

class SecondSubClassJob < TestJob
  before_run do |job_spec|
    history << 'SecondSubClassJob#before_run'
  end
end

class CancellingJob < TestJob
  before_run do |job_spec|
    false
  end
end

module Cascade
  describe "Job::Callbacks" do
    it "should run the before_queue callback before the job is added to the queue" do
      job_spec = TestJob.enqueue
      job = job_spec.job
      job.history.should == [:before_queue]
    end

    it "runs after_fork after forking the job" do
      job_spec = TestJob.enqueue(:raise_error)
      Worker.run_forked job_spec
      job_spec.reload['after_fork'].should be_true
    end

    it "should run before_queue, before_run, on_success and after_run callbacks on a successful job run" do
      job_spec = TestJob.enqueue
      job = job_spec.job
      Worker.run_job(job_spec, job)

      job.history.should == [:before_queue, :before_run, :on_success, :after_run]
    end

    it "should run before_queue, before_run, on_error and after_run callbacks on a successful job run" do
      job_spec = TestJob.enqueue(:raise_error)
      job = job_spec.job
      Worker.run_job(job_spec, job)

      job.history.should == [:before_queue, :before_run, :on_error, :after_run]
    end

    context "on a sub class" do
      it "should run the parent callbacks on a successful job run" do
        job_spec = SubClassJob.enqueue
        job = job_spec.job
        Worker.run_job(job_spec, job)

        job.history.should == [:before_queue, :before_run, :on_success, :after_run]
      end

      it "should run it's own callbacks along with the parent callbacks on a successful job run" do
        job_spec = SecondSubClassJob.enqueue
        job = job_spec.job
        Worker.run_job(job_spec, job)

        job.history.should == [:before_queue, :before_run, 'SecondSubClassJob#before_run', :on_success, :after_run]
      end
    end

    context "on a deep sub class" do
      it "runs the parent's parent callbacks" do
        job_spec = SubSubClassJob.enqueue
        job = job_spec.job
        Worker.run_job(job_spec, job)

        job.history.should == [:before_queue, :before_run, :on_success, :after_run]
      end
    end

    it "can cancel itself in the before_run callback by returning false" do
      job_spec = CancellingJob.enqueue
      job = job_spec.job
      Worker.run_job(job_spec, job)

      job.history.should == [:before_queue, :before_run, :after_run]
    end
  end
end
