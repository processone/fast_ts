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
  Sends an email. Mailman module is used to send email.
  You can define email sending parameters in `config.exs` file as follow:

  # Configure MailMan to be able to send email
  config :mailman,
    relay: "localhost",
    port: 1025,
    auth: :never
  """
  def email(to_address), do: {:stateless, &(do_email(&1, to_address))}
  def do_email(event = %Event{metric_f: _metric}, to_address) do
    # Compose email
    email = %Mailman.Email{
     subject: "#{event.host} #{event.service} #{event.state}",
      from: "no-reply@process-one.net",
      to: [ to_address ],
      # TODO show "No Description" if there is no description
      text: "#{event.host} #{event.service} #{event.state} (#{event.metric_f})\nat #{Common.epoch_to_string(event.time)}\n\n#{event.description}"
      }
    Mailman.deliver(email, %Mailman.Context{})
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

  @doc """
  Passes on events only when their metric is greater than x
  """
  def over(value), do: {:stateless, &(do_over(&1, value))}
  def do_over(event = %Event{metric_f: metric}, value) do
    cond do
      metric > value ->
        event
      true ->
        nil
    end
  end

  @doc """
  Scale metrics by the given factor
  """
  def scale(factor), do: {:stateless, &(do_scale(&1, factor))}
  def do_scale(event = %Event{metric_f: metric}, factor), do: %{event | metric_f:  metric * factor}


  @doc """
  Generic filtering. Filter events based on given function.
  The filtering function should no have side effects and must return true|false or fail with FunctionClauseError
  """
  def filter(f), do: {:stateless, &(do_filter(&1, f))}
  def do_filter(event = %Event{}, f) do 
          try do
                  if f.(event) do
                          event
                  else
                          nil
                  end
          rescue 
                FunctionClauseError -> nil 
                # treat these as false. Allows easy filtering like fn %Event{service :"some"} -> true end
                # without having to provide the false clause
          end

  end

  @doc """
  Generic map. Map (project) events using the given map function.
  The map function should no have side effects
  """
  def map(f), do: {:stateless, &(do_map(&1, f))}
  def do_map(event = %Event{}, f), do: f.(event) 


  def tag(tag), do: {:stateless, &do_tag(&1, (if is_list(tag), do: tag , else: [tag] ))}
  def do_tag(event = %Event{tags: tags}, new_tags) do
        %{event | tags: Enum.uniq(Enum.concat(tags, new_tags))}
  end

  def tagged_all(tag), do: {:stateless, &do_tagged_all(&1, (if is_list(tag), do: tag , else: [tag] ))}
  def do_tagged_all(event = %Event{tags: tagged}, tags) do
        if Enum.all?(tags, fn t ->  Enum.member? tagged, t end), do: event, else: nil
  end

  def tagged_any(tag), do: {:stateless, &do_tagged_any(&1, (if is_list(tag), do: tag , else: [tag] ))}
  def do_tagged_any(event = %Event{tags: tagged}, tags) do
        if Enum.any?(tags, fn t ->  Enum.member? tagged, t end), do: event, else: nil
  end


  # == Statefull processing functions ==
  def sreduce(f), do: sreduce(f, :first_event)
  def sreduce(f, init), do: {:stateful, &(sreduce(&1, &2, f, init))}
  def sreduce(context, pid, f, init) do
    fn ev ->
        {new,output} = case {FastTS.Stream.Context.get(context, :sreduce), init} do
            {nil, :first_event} ->
                {f.(ev, ev), nil}
            {nil, val} ->
                r = f.(val, ev)
                {r, r}
            {prev, _} ->
                r = f.(prev, ev)
                {r, r}
        end
        FastTS.Stream.Context.put(context, :sreduce, new)
        output
    end
  end

  def throttle(n, secs), do: {:stateful, &(throttle(&1, &2, n, secs))}
  def throttle(context, pid, n, secs) do
    fn(ev) ->
        now =  System.system_time(:seconds)
        case FastTS.Stream.Context.get(context, :throttle) do
            {start, count} when (now - start <= secs) and count >= n ->
                nil #these ones are to be discarded
            {start, count} when (now - start <= secs) and count < n ->
                FastTS.Stream.Context.put(context, :throttle, {start, count + 1})
                ev
            _ ->
                # first time, or previous window already expired.  Create new window.
                FastTS.Stream.Context.put(context, :throttle, {now, 1})
                ev
        end
    end
  end

  @doc """
  Stable output.  Output stable events.  It is defined as stable if for all events e_1,e_2,e_n
  in n sec,  f(e_1) = f(e_2) = f(e_3)
  """
  def stable(interval, f), do: {:stateful, &(stable(&1, &2, interval, f))}
  def stable(context, pid, interval, f) do
    FastTS.Stream.Context.put(context, :last, :undefined)
    fn(ev) ->
        now =  System.system_time(:seconds)
        current = f.(ev)
        case FastTS.Stream.Context.get(context, :last) do
            :undefined ->
                FastTS.Stream.Context.put(context, :last, current)
                FastTS.Stream.Context.put(context, :last_ts, now)
            ^current ->
                if now - FastTS.Stream.Context.get(context, :last_ts) >= interval do
                    ev
                else
                    nil
                end
            other ->
                FastTS.Stream.Context.put(context, :last, current)
                FastTS.Stream.Context.put(context, :last_ts, now)
                nil
        end
    end
  end

  @doc """
  Generic change detection.
  Detect changes in f(ev) for ev grouped in g(ev).
  Events that remains stable aren't propagated.
  """
  def changed(f,init, g), do: {:stateful, &(changed(&1, &2, f, init, g))}
  def changed(context, pid, f, init, g) do
    fn(ev) ->
        group = g.(ev)
        current = f.(ev)
        prev = FastTS.Stream.Context.get(context, group)
        prev = if is_nil(prev), do: init, else: prev
        if prev == current do
            nil
        else
            FastTS.Stream.Context.put(context, group, current)
            ev
        end
    end
  end

  @doc """
  Detect changes in state grouped by {host,service} pairs
  For a more general change detector use changed/3 instead
  """
  def changed_state(init) do
      f =  fn %Event{state: state} -> state end
      g =  fn %Event{host: host, service: service} -> {host, service} end
      {:stateful, &(changed(&1, &2, f, init, g))}
  end
  
  @doc """
  n events must have the same computed value.  Pass the last one of the n
  """
  def runs(n, f), do: {:stateful, &(runs(&1, &2, n, f))}
  def runs(context, pid, n, f) do
    fn(ev) ->
        current = f.(ev)
        runs = FastTS.Stream.Context.get(context, :runs)
        case runs do
            {^current, l} when l >= n ->
                ev
            {^current, l} ->
                FastTS.Stream.Context.put(context, :runs, {current, l + 1})
                nil
            _ ->
                # This is the first one detected, next o one is expected to be number 2
                FastTS.Stream.Context.put(context, :runs, {current, 2})
                nil
        end
    end
  end

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
    startTS = System.system_time(:seconds)
    :timer.apply_interval(interval * 1000, Kernel, :apply, [ __MODULE__, :switch_partition, [context, startTS, create, finish]])
    add
  end

  # TODO: test against race condition between state reset and message that could arrive in-between
  # We can probably add a first clause in receive to reset state in the event receiving loop
  def switch_partition(context, startTS, create, finish) do
    dataMap = FastTS.Stream.Context.get_all(context)
    create.()
    endTS = System.system_time(:seconds)
    finish.(dataMap, startTS, endTS)
  end
end

# function:
# info -> log object to file
# Elixir: Several log levels

# Event.time is unix time in seconds
