defmodule FastTS.Supervisor do
  use Supervisor

  require Logger
  require File
  require Path

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
    get_route_files |> Enum.map(fn(file) -> Code.load_file file end)
  end
  
  defp get_route_files do
    case get_route_dir do
      nil ->
        Logger.warning "No fast_ts route_dir configured: Using route file 'config/route.exs'"
        ["config/route.exs"]
      route_dir ->
        {:ok, files} = File.ls(route_dir)
        exs_files = Enum.reduce(files, [],
          fn(file, acc) ->
            cond do
              Path.extname(file) == ".exs" ->
                [Path.join(route_dir, file)|acc]
              true ->
                acc
            end
          end)
        case exs_files do
          [] ->
            Logger.error "No .exs file in route_dir"
            # TODO register a default dumb pipeline that output everything to logs
            []
          _ ->
            exs_files
        end
    end
  end

  # First try to read route dir from FTS_ROUTE_DIR environment
  # variable, then try value from config file
  defp get_route_dir do
    env_route_dir = System.get_env("FTS_ROUTE_DIR")
    case env_route_dir do
      nil ->
        Application.get_env(:fast_ts, :route_dir)
      _ ->
        env_route_dir
    end
  end
end
