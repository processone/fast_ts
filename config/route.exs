defmodule HelloFast.Router do
  use FastTS.Router

  # When build, we will have a new function to call:
  # iex(1)> HelloFast.Router."Calculate Rate and Broadcast"
  # We are running pipeline CRaB
  # :ok
  pipeline "Calculate Rate and Broadcast" do
    IO.puts "We are running pipeline CRaB"
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
