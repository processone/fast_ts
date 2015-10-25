defmodule FastTS.Supervisor do
  use Supervisor

  def start_link do
    set_routes
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    streams = Enum.map(HelloFast.Router.streams,
      fn({name, pipeline}) -> worker(FastTS.Stream.Pipeline, [name, pipeline]) end)
    children = streams ++
      [
        #supervisor(FastTS.Stream.Supervisor, []),
        # TODO: Make port configurable
        worker(Task, [FastTS.Server, :accept, [5555]])
      ]
    supervise(children, strategy: :one_for_one)
  end

  # TODO set_routes should be part of the pipeline supervision process
  defp set_routes do
    # TODO: Read file name from config
    Code.load_file "config/route.exs"
  end

end
