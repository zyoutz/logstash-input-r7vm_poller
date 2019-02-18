# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/r7vm_poller"

describe LogStash::Inputs::R7vmPoller do

  it_behaves_like "an interruptible input plugin" do
    let(:config) { { "interval" => 100 } }
  end

end
