defmodule FastTS.Stream.Pipeline do
  use GenServer

  @type pipeline :: list({:stateful, fun})
  @spec start_link(name :: string, pipeline :: pipeline) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_name, []), do: :ignore
  def start_link(name, pipeline) do
    GenServer.start_link(__MODULE__, [name, pipeline])
  end

  # Create a chained list of process to pass events through the pipeline
  # A pipeline is composed of a list of 'start' anonymous function. start function
  # They return the function to perform to add an event.
  # pipeline = [{"stateful, start_fun/2}]
  # Stateful start_fun takes parameters ets_table and pid of the next process in pipeline
  # stateless fun directly pass a basic add event fun receiving event as parameter. They bypass the ets table creation
  def init([name, pipeline]) do
    process = process_name(name)
    pipeline
    |> Enum.reverse
    |> Enum.reduce(
      nil,
      fn({:stateful, start_fun}, pid) ->
          spawn_link( fn -> set_loop_state(start_fun, pid) end )
        ({:stateless, add_event_fun}, pid) ->
          spawn_link( fn -> do_loop(add_event_fun, pid) end)
      end)
    |> Process.register(process)
    
    state = [process, pipeline]
    {:ok, state}
  end

  def next(_result, nil), do: :nothing
  def next(:defer, _pid), do: :nothing
  def next(nil, _pid), do: :nothing
  def next(result, pid), do: send(pid, result)

  # We start one loop per steps in the pipeline. Each pipeline step is a process.
  #E
  # TODO create a supervisor per pipeline, place each pipeline supervisor under a stream supervisor
  # TODO Optimize that: For now we create one ETS per loop. ETS table is only needed when we are using time buckets. We do not need to create it otherwise
  # TODO One table ETS per stateful pipeline stage is propably overkill. We may have one ETS table per stream or even one ETS table for all
  # = More generally, I need to refactor how the state are kept
  def set_loop_state(start_fun, pid) do
    # TODO: for now the name is fix, so it will not work for many pipelines
    table = :ets.new(:pipeline_stage_data, [:public])
    add_event_fun = start_fun.(table, pid)
    do_loop(add_event_fun, pid)
  end

  def do_loop(fun, pid) do
    receive do
      # TODO we can probably receive an event to reset state in the loop to avoid race condition between receive event / reset
      event ->
        event
        |> fun.()
        |> next(pid)
    end
    do_loop(fun, pid)
  end

  # Helper
  defp process_name(name) when is_atom(name), do: name
  defp process_name(name) when is_binary(name), do: String.to_atom(name)
  
end
