defmodule HelloFast.Router do
  use FastTS.Router
  
#  pipeline "Calculate Rate and Broadcast" do
    # filter(is_server(%Event{host: "localhost"}))
#    IO.puts "We are running pipeline CRaB"
#  end

  pipeline "Basic pipeline" do
    Stream.stdout
  end
  
  # For now, we assume that we can only put pipeline function in the block
  # TODO We need to add more consistency checks on the content of the pipeline
  pipeline "Second pipeline" do
    Stream.rate(5)
    Stream.stdout
  end

  pipeline "Empty pipeline should be ignored" do
  end
  
  # TODO we need filter / matching
  #pipeline localhost(%Event{host: "localhost"}) do
  # rate(5)
  # stdout
  #end
  
end
