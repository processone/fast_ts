defmodule HelloFast.Router do
  use FastTS.Router

  pipeline "Basic pipeline" do
    # We only take functions under a given value
    over(12)
    email("mremond@test.com")
    stdout
  end

  # For now, we assume that we can only put pipeline function in the block
  # TODO We need to add more consistency checks on the content of the pipeline
  pipeline "Second pipeline" do
    rate(5)
    stdout
  end

  pipeline "Empty pipeline are ignored" do
  end

  pipeline "Scale metrics" do
  scale(15)
  stdout
  end

  pipeline "stabilize pipeline" do
  stable(5, fn %Event{state: s} -> s end)
  stdout
  end

  pipeline "tag" do
  tag("tag1") #add single tag
  tag(["tag2", "tag1", "tag3"]) #add multiple tags. Duplicates are removed
  stdout
  end

  pipeline "Generic filtering and mapping" do
  filter(fn %Event{service: "eth0" <> _} -> true end)   #filter events with service starting with "eth0".  
  map(fn x -> %{x | service: "net"} end)  
  stdout
  end

  pipeline "State change detection" do
  changed_state("up")
  stdout
  end

  pipeline "Generic change detection" do
  # This has the same effect than the State change detection pipeline
  changed(fn %Event{state: state} -> state end, "up",
                fn %Event{host: host, service: service} -> {host, service} end)
  stdout
  end

  pipeline "consecutive runs" do
  runs(3, fn %Event{state: state} -> state end)
  stdout
  end

  pipeline "throttle" do
  throttle(2,5)  #at most 2 events each 5 seconds
  stdout
  end

  # TODO we need filter / matching
  # pipeline localhost(%Event{host: "localhost"}) do
  #   rate(5)
  #   stdout
  # end

  # pipeline "Calculate Rate and Broadcast" do
  #   filter(is_server(%Event{host: "localhost"}))
  #   IO.puts "We are running pipeline CRaB"
  # end


end
