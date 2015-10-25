defmodule HelloFast.Router do
  # use FastTS.Router

  alias RiemannProto.Event
  alias FastTS.Stream

  #defstream localhost(%Event{host: "localhost"} do
  # rate(5)
  # stdout
  #end

  # previous code should generate:

  # TODO: Check if pipeline length is < 0 and do not generate stream
  def streams do
    stream1 = {:localhost, [Stream.rate(5), Stream.stdout]}
    [stream1]
  end
  
  def stream(event = %Event{host: "localhost"}) do
    name = :localhost
    send name, event
  end
  # Catch all case: We have no stream matching that event
  def stream(_), do: :do_nothing

end
