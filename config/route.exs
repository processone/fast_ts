defmodule HelloFast.Router do
  use FastTS.Router
  
  pipeline "Calculate Rate and Broadcast" do
    # filter(is_server(%Event{host: "localhost"}))
    IO.puts "We are running pipeline CRaB"
  end

  # For now, we assume that we can only put pipeline function in the block
  pipeline "Second pipeline" do
    Stream.rate(5)
    Stream.stdout
  end

  pipeline "Return list of steps" do
    [Stream.rate(5), Stream.stdout]
  end

  pipeline "Empty pipeline should be ignored" do
  end
  
  #pipeline localhost(%Event{host: "localhost"}) do
  # rate(5)
  # stdout
  #end

  # previous code should generate:
  
  # TODO: Check if pipeline length is < 0 and do not generate stream
  def streams do
    stream1 = {:localhost, [Stream.rate(5), Stream.stdout]}
    [stream1]
  end

  def stream(event) do
    streams |>
      Enum.each( fn({name, _pipeline}) -> do_stream(name, event) end)
  end
  
  def do_stream(name = :localhost, event = %Event{host: "localhost"}) do
    send name, event
  end
  # Catch all case: We have no stream matching that event
  def do_stream(_, _), do: :do_nothing
   
end
