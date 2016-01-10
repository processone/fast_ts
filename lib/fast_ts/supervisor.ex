defmodule FastTS.Supervisor do
  use Supervisor

  def start_link do
    set_routes
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    # TODO: We generate a spec id based on index, but pipeline id
    # should probably be generated when compiling the router
    modules = FastTS.Router.Modules.get |> Enum.reduce([], fn(module, acc) ->
      apply(module, :streams, []) ++ acc
    end)

    streams = Enum.map(Enum.with_index(modules),
      fn({{name, pipeline}, index}) ->
        worker(FastTS.Stream.Pipeline, [name, pipeline], id: index ) end)
    children = streams ++
      [
        # TODO: Make port configurable
        worker(Task, [FastTS.Server, :accept, [5555]])
      ]
    supervise(children, strategy: :one_for_one)
  end

  # TODO set_routes should be part of the pipeline supervision process
  # -> Or maybe not, as of today, pipeline steps are linked process, the whole pipeline is restarted in case of crash, which is what we want
  defp set_routes do
    FastTS.Router.Modules.start_link()
    Code.load_file "config/route.exs"
  end

end
