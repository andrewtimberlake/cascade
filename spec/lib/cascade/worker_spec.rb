require 'spec_helper'

module Cascade
  describe Worker do
    context "when queueing a job" do
      before do
        Timecop.freeze
      end

      after do
        Timecop.return
      end

      let!(:job_spec) { Worker.enqueue(MyJob, :one, :two) }

      it "creates a job spec with the specified class" do
        job_spec.class_name.should eql('MyJob')
      end

      it "creates a job spec with the correct arguments" do
        job_spec.arguments.should eql([:one, :two])
      end

      it "creates a job spec with a default priority of 1" do
        job_spec.priority.should eql(1)
      end

      it "creates a job spec with a default run time of now" do
        job_spec.run_at.should eql(Time.now.utc)
      end

      context "with options" do
        let!(:job_spec) { Worker.enqueue(MyJob, :one, :two, :priority => -5, :run_at => 5.minutes.from_now) }

        it "creates a job spec with the correct arguments" do
          job_spec.arguments.should eql([:one, :two])
        end

        it "creates a job spec with a priority of -5" do
          job_spec.priority.should eql(-5)
        end

        it "creates a job spec with a run time of 5 minutes from now" do
          job_spec.run_at.should eql(5.minutes.from_now)
        end
      end

      context "with options (and the job takes an options hash)" do
        let!(:job_spec) { Worker.enqueue(MyJob, :one, :two, :three => 3, :four => 4, :priority => -5, :run_at => 5.minutes.from_now) }

        it "creates a job spec with the correct arguments" do
          job_spec.arguments.should eql([:one, :two, {:three => 3, :four => 4}])
        end
      end
    end

    context "when running all jobs" do
      before do
        MyJob.enqueue
        ErrorJob.enqueue

        result = Worker.new(1).run

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

    context "when the job raises an error" do
      let(:job_spec) { ErrorJob.enqueue }

      before do
        job_spec
        Worker.new(1).run
      end

      it "should set the last error if a job fails" do
        job_spec.reload
        job_spec.last_error.should_not be_nil
      end

      it "should set failed_at if a job fails" do
        job_spec.reload
        job_spec.failed_at.should_not be_nil
      end

      it "should clear locked_by if a job fails" do
        job_spec.reload
        job_spec.locked_by.should be_nil
      end

      it "should clear locked_at if a job fails" do
        job_spec.reload
        job_spec.locked_at.should be_nil
      end

    end

    context "when the job raises an exception" do
      let(:job_spec) { ExceptionJob.enqueue }

      before do
        job_spec
        Worker.new(1).run
      end

      it "should set the last error if a job fails" do
        job_spec.reload
        job_spec.last_error.should_not be_nil
      end

      it "should set failed_at if a job fails" do
        job_spec.reload
        job_spec.failed_at.should_not be_nil
      end

      it "should clear locked_by if a job fails" do
        job_spec.reload
        job_spec.locked_by.should be_nil
      end

      it "should clear locked_at if a job fails" do
        job_spec.reload
        job_spec.locked_at.should be_nil
      end

    end

    context "when the job fails" do
      let(:job_spec) { CatastrophicFailureJob.enqueue }

      before do
        job_spec
        Worker.new(1).run
      end

      it "should the last error if a job fails" do
        job_spec.reload
        job_spec.last_error.should_not be_nil
      end

      it "should set failed_at if a job fails" do
        job_spec.reload
        job_spec.failed_at.should_not be_nil
      end

      it "should clear locked_by if a job fails" do
        job_spec.reload
        job_spec.locked_by.should be_nil
      end

      it "should clear locked_at if a job fails" do
        job_spec.reload
        job_spec.locked_at.should be_nil
      end

    end

    context "when a job is set to re-run" do
      let(:job_spec) { RepeatableJob.enqueue }

      before do
        job_spec
        Worker.new(1).run
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

    context "displaying the job queue" do
      before do
        js = RepeatableJob.enqueue
        js.update_attributes(:last_error => 'Test Error', :failed_at => Time.now.utc)

        js = ErrorJob.enqueue
        js.update_attributes(:locked_by => 'TestRunner', :locked_at => Time.now.utc)
      end

      it "should show the job counts" do
        results = Worker.queue
        results['ErrorJob'][:count].should eql(1)
        results['RepeatableJob'][:count].should eql(1)
      end

      it "show the running counts" do
        results = Worker.queue
        results['ErrorJob'][:running].should eql(1)
        results['RepeatableJob'][:running].should eql(0)
      end

      it "show the failed counts" do
        results = Worker.queue
        results['ErrorJob'][:failed].should eql(0)
        results['RepeatableJob'][:failed].should eql(1)
      end
    end

    context "when the worker exits" do
      let!(:job_spec) { Worker.enqueue(ExitableJob) }

      it "gives the job an option to exit early" do
        pid = fork do
          trap(:TERM) { $exit = true; }
          Worker.new(1).start
        end
        sleep 0.5
        Process.kill(:TERM, pid)
        sleep 0.1
        Timeout::timeout(2) do
          Process.wait(pid)
        end
      end
    end
  end
end
