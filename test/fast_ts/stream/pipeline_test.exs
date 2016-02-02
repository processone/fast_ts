defmodule FastTS.Stream.PipelineTest do
  use ExUnit.Case

  test "Ignore empty pipeline" do
    assert FastTS.Stream.Pipeline.start_link(:empty, []) == :ignore
  end

  test "Create a one step pipeline" do
    test_pid = self
    start_fun = fn _ets_table, next_pid ->
      send test_pid, {:from, :started, self}
      fn(event) -> event end
    end
    
    {:ok, _pid} = FastTS.Stream.Pipeline.start_link(:pipe1, [{:stateful, start_fun}])
    
    receive do
      {:from, :started, step1_pid} ->
        assert Process.alive?(step1_pid)
    after 5000 ->
        assert false, "pipeline process not properly started"
    end
  end

end
