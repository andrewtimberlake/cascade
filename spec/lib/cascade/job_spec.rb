require 'spec_helper'

module Cascade
  describe Job do
    let(:job) { MyJob.new() }

    context "#describe" do
      it "describes itself" do
        job.describe.should == 'MyJob'
      end
    end

    context "#enqueue" do
      it "adds itself to the queue" do
        Worker.should_receive(:enqueue).with(MyJob, :one, :two)
        MyJob.enqueue(:one, :two)
      end
    end
  end
end
