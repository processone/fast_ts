defmodule FastTS.Stream.Filter do

  # TODO: need to be able to create downstreams on-demand by the filter fun.
  # That's needed for by () operator.  But maybe it can be done for all? so operators
  # create their children on-demand?.  Must have a way to create new ones 
  # Or, could have a "downstream_template" option.  If the downstream spec isn't found,
  # it instantiate a new downstream using the template?


  defp start_childs({key, childs}) when is_list(childs) do
    {key, Enum.map(childs, &start/1)}
  end
  defp start_childs({key, child}) when is_tuple(child) do
    {key, [start child]} 
  end

  def start({:flowop,f, state, options, downstreams}) do
    downstreams = Enum.map downstreams, &start_childs/1
    spawn_link(fn -> loop(state, f, :infinity, options, downstreams) end)
  end

  defp loop(state, f, timeout, options, downstreams) do
    receive do
      ev ->
        inject(ev, f, state, options, downstreams)
      after timeout ->
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
    updated_downstreams = flow(output, downstreams, Keyword.get(options, :downstream_spec))
    loop(new_state, f, timeout, options, updated_downstreams)
  end
     
end


