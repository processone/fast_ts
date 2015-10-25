defmodule FastTS do
  use Application

  def start(_type, _args) do
    FastTS.Supervisor.start_link
  end

end
