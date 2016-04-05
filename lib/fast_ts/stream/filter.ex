defmodule FastTS.Stream.Filter do
  # TODO: the start/start_childs/start_downstreams function here should be better of
  # splitting in another module that takes care of instantiating the pipeline
  

  defp start_childs({key, childs}, ctx) when is_list(childs) do
    {pids, ctx} = Enum.reduce(childs, {[],ctx}, fn(child, {pids,ctx}) ->   
      {pid, ctx} = start(child, ctx)
      {[pid | pids], ctx}
    end)
    { {key, pids}, ctx}
  end

  defp start_childs({key, child}, ctx) when is_tuple(child) do
    start_childs({key, [child]}, ctx)
  end
  
  defp start_downstreams([], accum, ctx), do: {accum, ctx}
  defp start_downstreams([childs | rest], accum, ctx) do
    {r, ctx} = start_childs(childs, ctx)
    start_downstreams(rest, [r|accum], ctx)
  end

  # Start without dedup filters. This will create a *new* process each time called,
  # used for example when child pipelines must be instantiated on-demand by the 'by' operation.
  def start({:flowop,f, state, options, downstreams}=def) do
      {pid, _} = start(def, [])
      pid
  end


  # Instantiate this filter' process, if not exist already.
  # This is ugly as it rellies on phisical equality, would be better to 
  # have each filter generate a unique ID to identify itself when building the pipeline tree.
  # Note:  normal equality ( == ) won't be enough here. We want to know if the filter are the same instance,
  # not that their are merely equal.
  def start({:flowop,f, state, options, downstreams}=def, ctx) do
    case Enum.find ctx,  fn({k,pid}) -> :erts_debug.same(k, def) end do
      nil ->
        # This particular instance of filter not yet created. Launch it and add to ctx
        {downstreams, ctx} = start_downstreams(downstreams, [], ctx)
        pid =  spawn_link(fn -> loop(state, f, :infinity, options, downstreams) end)
        {pid, [{def,pid} | ctx]}
      {_, pid} ->
        {pid, ctx}
    end
  end

  defp loop(state, f, timeout, options, downstreams) do
    receive do
      ev ->
        #IO.puts "#{inspect self()} got #{inspect ev}"
        inject(ev, f, state, options, downstreams)
      after max(0, timeout) ->
        inject(:timeout, f, state, options, downstreams)
     end
   end


  defp opts([]), do: []
  defp opts([:mt|rest]), do: [{:mt, System.monotonic_time(:milli_seconds)} | opts(rest)]
  defp opts([_|rest]), do: opts(rest)


  defp flow([], downstreams, template), do: downstreams
  defp flow([{key,ev} | rest], downstreams, template) do
    updated_downstreams = case List.keyfind(downstreams, key, 0, :not_found) do 
      {key, pids} -> 
        Enum.each pids, &(send(&1, ev))
        downstreams
      :not_found -> 
        case template do
           :nil  -> downstreams
           t ->  
            new_child = start(t)
            send(new_child, ev)
            [{key, [new_child]} | downstreams]
        end
    end
    flow(rest, updated_downstreams, template) 
  end

  defp inject(ev, f, state, options, downstreams) do
    {new_state, output, timeout} = f.(state, ev, opts(options))
    #IO.puts "#{inspect self()} outout #{inspect output}"
    updated_downstreams = flow(output, downstreams, Keyword.get(options, :downstream_spec))
    loop(new_state, f, timeout, options, updated_downstreams)
  end




  # Setup a pipeline, with shared components, and send some sample events through it
  def test_pipeline() do
    alias RiemannProto.Event
    import FastTS.Stream
    # taken from the pipe example on reimann.
    # tag events as "critical|warning|info" acording to their metric, and send all to the throttled-mailer pipeline.
    # events below 0.5 aren't  reported.
    # As the throttled_emailer is the *same instance* for all, this will print only 5 events per second, regardless of the tag level.
    # different that repeating the throttle2() directly as child of each one, as those will result in *different instances* of the throttle,
    # so printing up to 5 per second of  "critical",  up to 5 per second of "warning", etc.
    # note the syntax for retrieving the event metric value (fn %Event{metric_f: m} -> m end) is too raw, helpers can be made like just a metric/1 fun
    # or perhaps those already exists as part of protobuf' code generation/elixir maps, check that.

    throttled_emailer = throttle2(5, 1) do   #at most 5 each 1 second
                          print2
                         end

    pipeline = splitp(&</2, fn %Event{metric_f: m} -> m end,
                        [{0.9, tag2("critical", do: throttled_emailer)},
                         {0.75, tag2("warning", do: throttled_emailer)},
                         {0.50, tag2("info", do: throttled_emailer)}
                         ])
    p =  start(pipeline)

    Enum.each (1..10), (fn s -> Enum.each [0.95, 0.79, 0.10, 0.05, 0.51], &(send(p, %Event{tags: ["iter-#{s}"], metric_f: &1})) end)
    p
  end
     
end


