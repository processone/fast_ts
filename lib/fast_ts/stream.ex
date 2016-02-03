## These are the components for the stream library
defmodule FastTS.Stream do
  alias RiemannProto.Event

    # TODO: I think the block need to be able to receive the module
    # the pipeline is living in to read module attributes, to pass or
    # overload special configuration informations
  
  # == Output functions ==
  
  @doc """
  Prints event struct on stdout
  """
  def stdout, do: {:stateless, &do_stdout/1}
  def do_stdout(event) do
    IO.puts "#{inspect event}"
    event
  end

  @doc """
  Sends an email
  """
  def email(to_address), do: {:stateless, &(do_email(&1, to_address))}
  def do_email(event = %Event{metric_f: _metric}, to_address) do
    # TODO: Move configuration in standard config.exs and / or in module attributes
    config =  %Mailman.Context{
      config: %Mailman.SmtpConfig{
        relay: "localhost",
        port: 1025,
        auth: :never}
    }
    # Compose email
    email = %Mailman.Email{
     subject: "#{event.host} #{event.service} #{event.state}",
      from: "no-reply@process-one.net",
      to: [ to_address ],
      # TODO show "No Description" if there is no description
      text: "#{event.host} #{event.service} #{event.state}\nat {event time}\n\n#{event.description}"
      }
    Mailman.deliver(email, config)
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
  def rate(context, pid, interval) do
    partition_time(context, interval,
                   # Create :
                   fn ->
                     # TODO add wrapper around ets table operations: pass a list of key values (data), receive a list of key values (data)
                     FastTS.Stream.Context.put(context, :count, 0)
                     FastTS.Stream.Context.put(context, :state, nil)
                   end,
                   # Add event and defer passing to next pipeline stage :
                   fn(event = %Event{metric_f: metric}) ->
                     count = FastTS.Stream.Context.get(context, :count)
                     FastTS.Stream.Context.put(context, :count, count + (metric||0))
                     FastTS.Stream.Context.put(context, :state, event)
                     :defer
                   end,
                   # Finish = On interval, reset state event to next pipeline stage :
                   fn(dataMap, startTS, endTS) ->
                     case dataMap[:state] do
                       nil -> # If no event were send during interval, do nothing
                         FastTS.Stream.Pipeline.next(nil, pid)
                       event -> # Otherwise calculate rate, replace metric with that value and pass last event down the pipeline
                         count = dataMap[:count]
                         rate = Float.round(count / (endTS - startTS), 3)
                         FastTS.Stream.Pipeline.next(%{event | time: endTS, metric_f: rate}, pid)
                     end
                   end)
  end
  
  # TODO: when we want to stop stream, we need to stop timer
  defp partition_time(context, interval, create, add, finish) do
    create.()
    startTS = :erlang.system_time(:seconds)
    :timer.apply_interval(interval * 1000, Kernel, :apply, [ __MODULE__, :switch_partition, [context, startTS, create, finish]])
    add
  end

  # TODO: test against race condition between state reset and message that could arrive in-between
  # We can probably add a first clause in receive to reset state in the event receiving loop
  def switch_partition(context, startTS, create, finish) do
    dataMap = FastTS.Stream.Context.get_all(context)
    create.()
    endTS = :erlang.system_time(:seconds)
    finish.(dataMap, startTS, endTS)
  end
end

# function:
# info -> log object to file
# Elixir: Several log levels
