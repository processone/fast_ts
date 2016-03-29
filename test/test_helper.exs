ExUnit.start()



defmodule FastTSTestHelper do

  # We might use a lib for this in case we need more complex data to be generated. 
  # there is faker and ExMachina.  
  def create(:event), do: %RiemannProto.Event{metric_f: :random.uniform() * 10, state: Enum.random(["ok", "down"]), host: "h" , service: "s"}

end
