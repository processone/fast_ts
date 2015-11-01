defmodule FastTS.Stream.PipelineTest do
  use ExUnit.Case

  test "Ignore empty pipeline" do
    assert FastTS.Stream.Pipeline.start_link(:test, []) == :ignore
  end
  
#  test "Create pipeline one step" do
#    create_fun = fn()
#    {:ok, Pid} = FastTS.Stream.Pipeline.start_link(:test, [])
#  end

end
