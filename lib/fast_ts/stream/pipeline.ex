defmodule FastTS.Stream.Pipeline do
  use GenServer

  @type pipeline :: list(fun)
  @spec start_link(name :: atom, pipeline :: pipeline) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_name, []), do: :ignore
  def start_link(name, pipeline) do
    GenServer.start_link(__MODULE__, [name, pipeline])
  end

  # Create a chained list of process to pass events through the pipeline
  def init([name, pipeline]) do
    pipeline
    |> Enum.reverse
    |> Enum.reduce(
      nil,
      fn(fun, acc) ->
        spawn_link( fn -> block_loop(fun, acc) end )
      end)
    |> Process.register(name)
    
    state = [name, pipeline]
    {:ok, state}
  end

  def next(_result, nil), do: :nothing
  def next(:defer, _pid), do: :nothing
  def next(nil, _pid), do: :nothing
  def next(result, pid), do: send pid, result

  # We start one loop per steps in the pipeline
  # 
  # TODO create a supervisor per pipeline, place each pipeline supervisor under a stream supervisor
  # TODO we need two types of loops: One for time partition and the other for immediate processing (could be automatically dispatched or selected if interval is 0)
  # TODO Optimize that: For now we create one ETS per loop. ETS table is only needed when we are using time buckets. We do not need to create it otherwise
  # TODO One table ETS per pipeline stage is propably overkill. We may have one ETS table per stream or even one ETS table for all
  def block_loop(start_fun, pid) do
    table = :ets.new(:pipeline_stage_data, [:public])
    add_event_fun = start_fun.(table, pid)
    do_block_loop(add_event_fun, pid)
  end

  defp do_block_loop(fun, pid) do
    receive do
      # TODO we can probably receive an event to reset state in the loop to avoid race condition between receive event / reset
      event ->
        event
        |> fun.()
        |> next(pid)
    end
    do_block_loop(fun, pid)
  end

end

