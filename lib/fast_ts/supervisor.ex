defmodule FastTS.Supervisor do
  use Supervisor

  def start_link do
    set_routes
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    # TODO: We generate a spec id based on index, but pipeline id
    # should probably be generated when compiling the router
    streams = Enum.map(Enum.with_index(HelloFast.Router.streams),
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
    # TODO: Read file name from config
    Code.load_file "config/route.exs"
  end

end
