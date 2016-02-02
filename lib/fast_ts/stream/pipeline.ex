defmodule FastTS.Stream.Pipeline do
  use GenServer

  @type pipeline :: list({:stateful, fun}|{:stateless, fun})
  @spec start_link(name :: String.t, pipeline :: pipeline) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_name, []), do: :ignore
  def start_link(name, pipeline) do
    GenServer.start_link(__MODULE__, [name, pipeline])
  end

  # Create a chained list of process to pass events through the pipeline
  # A pipeline is composed of a list of 'start' anonymous function. start function
  # They return the function to perform to add an event.
  # pipeline = [{:stateful, start_fun/2}|{:stateless, add_event_fun/1}]
  # Stateful start_fun takes parameters ets_table and pid of the next process in pipeline
  # stateless fun directly pass a basic add event fun receiving event as parameter. They bypass the ets table creation
  def init([name, pipeline]) do
    process = process_name(name)
    pipeline
    |> Enum.reverse
    |> Enum.reduce(
      nil,
      fn({:stateful, start_fun}, next_pid) ->
          spawn_link( fn -> set_loop_state(start_fun, next_pid) end )
        ({:stateless, add_event_fun}, next_pid) ->
          spawn_link( fn -> do_loop(add_event_fun, next_pid) end)
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
  #
  # TODO create a supervisor per pipeline, place each pipeline supervisor under a stream supervisor
  def set_loop_state(start_fun, next_pid) do
    {:ok, context} = FastTS.Stream.Context.start_link
    add_event_fun = start_fun.(context, next_pid)
    do_loop(add_event_fun, next_pid)
  end

  def do_loop(fun, next_pid) do
    receive do
      # TODO we can probably receive an event to reset state in the loop to avoid race condition between receive event / reset
      event ->
        event
        |> fun.()
        |> next(next_pid)
    end
    do_loop(fun, next_pid)
  end

  # Helper
  defp process_name(name) when is_atom(name), do: name
  defp process_name(name) when is_binary(name), do: String.to_atom(name)
  
end
