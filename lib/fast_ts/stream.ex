## These are the components for the stream library
defmodule FastTS.Stream do
  alias RiemannProto.Event
  
  @doc """
  Print event struct on stdout
  """
  def stdout, do: &(stdout(&1, &2, 0))
  # TODO: can we simplify this and directly return do stdout ?
  def stdout(_ets, _pid, _interval), do: &(do_stdout(&1))
  def do_stdout(event) do
    IO.puts "#{inspect event}"
    event
  end

  @doc """
  Calculate rate of a given event per second, assuming metric is an occurance count

  Bufferize events for N second interval and divide total count by interval in second.
  On interval tick: 
  - passes the last event down the pipe, with metric remplaced with rate per second
  - Send a nil event down the pipe so that other pipe element can decide to generate one to fill the void
  """
  def rate(interval), do: &(rate(&1, &2, interval))
  def rate(ets, pid, interval) do
    partition_time(ets, interval,
      fn ->
        # TODO add wrapper around ets table operations: pass a list of key values (data), receive a list of key values (data)
        :ets.insert(ets, {:count, 0})
        :ets.insert(ets, {:state, nil})
      end,
      fn(event = %Event{metric_f: metric}) ->
        [count: count] = :ets.lookup(ets, :count)
        :ets.insert(ets, {:count, count + metric})
        :ets.insert(ets, {:state, event})
        :defer
      end,
      fn(data, startTS, endTS) ->
        case data[:state] do
          nil ->
            FastTS.Stream.Pipeline.next(nil, pid)
          event ->
            count = data[:count]
            rate = Float.round(count / (endTS - startTS), 3)
            FastTS.Stream.Pipeline.next(%{event | time: endTS, metric_f: rate}, pid)
        end
      end)
  end

  # TODO: when we when to stop stream, we need to stop timer
  defp partition_time(table, interval, create, add, finish) do
    create.()
    startTS = :erlang.system_time(:seconds)
    :timer.apply_interval(interval * 1000, Kernel, :apply, [ __MODULE__, :switch_partition, [table, startTS, create, finish]])
    add
  end

  # TODO: test against race condition between state reset and message that could arrive in-between
  # We can probably add a first clause in receive to reset state in the event receiving loop
  def switch_partition(table, startTS, create, finish) do
    data = :ets.tab2list(table)
    create.()
    endTS = :erlang.system_time(:seconds)
    finish.(data, startTS, endTS)
  end
end

# function:
# prn  -> print object to stdout
# Elixir:  stdout ?
# info -> log object to file
# Elixir: Several log levels
