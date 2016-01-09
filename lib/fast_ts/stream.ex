## These are the components for the stream library
defmodule FastTS.Stream do
  alias RiemannProto.Event

  # == Output functions ==
  
  @doc """
  Prints event struct on stdout
  """
  def stdout, do: {:stateless, &do_stdout/1}
  def do_stdout(event) do
    IO.puts "#{inspect event}"
    event
  end

  # == Filter functions ==
  
  @doc """
  Passes on events only when their metric is smaller than x
  """
  def under(value), do: {:stateless, &(do_under(&1, value))}
  def do_under(event = %Event{metric_f: metric}, value) do
    cond do
      metric < value ->
        event
      true ->
        nil
    end
  end

  # == Statefull processing functions ==
  
  @doc """
  Calculate rate of a given event per second, assuming metric is an occurence count
  
  Bufferize events for N second interval and divide total count by interval in second.
  On interval tick: 
  - passes the last event down the pipe, with metric remplaced with rate per second. Note that if event types are
    not homogeneous they would need to be filter / sorted properly before.
  - Send a nil event down the pipe so that other pipe element can decide to generate one to fill the void
  """
  def rate(interval), do: {:stateful, &(rate(&1, &2, interval))}
  def rate(ets, pid, interval) do
    partition_time(ets, interval,
                   # Create :
                   fn ->
                     # TODO add wrapper around ets table operations: pass a list of key values (data), receive a list of key values (data)
                     :ets.insert(ets, {:count, 0})
                     :ets.insert(ets, {:state, nil})
                   end,
                   # Add event and defer passing to next pipeline stage :
                   fn(event = %Event{metric_f: metric}) ->
                     [count: count] = :ets.lookup(ets, :count)
                     :ets.insert(ets, {:count, count + (metric||0)})
                     :ets.insert(ets, {:state, event})
                     :defer
                   end,
                   # Finish = On interval, reset state event to next pipeline stage :
                   fn(data, startTS, endTS) ->
                     case data[:state] do
                       nil -> # If no event were send during interval, do nothing
                         FastTS.Stream.Pipeline.next(nil, pid)
                       event -> # Otherwise calculate rate, replace metric with that value and pass last event down the pipeline
                         count = data[:count]
                         rate = Float.round(count / (endTS - startTS), 3)
                         FastTS.Stream.Pipeline.next(%{event | time: endTS, metric_f: rate}, pid)
                     end
                   end)
  end
  
  # TODO: when we want to stop stream, we need to stop timer
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
# info -> log object to file
# Elixir: Several log levels
