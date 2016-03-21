defmodule FastTS.Server do

  require Logger
  
  @doc """
  Starts accepting connections on the give `port`.
  """
  @spec accept(port :: integer) :: no_return
  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 4, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    pid = spawn(fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  def serve(socket) do
    Logger.debug "Client connected"
    result = socket |> read_message |> send_response
    case result do
      :stop ->
        :stop
      _ ->
        serve(socket)
    end
  end

  defp read_message(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        process_data(data)
        socket
      {:error, :closed} ->
        :stop
      {:error, reason} ->
        Logger.debug("Error reading message on socket: #{reason}")
        :stop
    end
  end

  defp send_response(:stop), do: :stop
  defp send_response(socket) do
    msg = RiemannProto.Msg.encode(RiemannProto.Msg.new(ok: true))
    :gen_tcp.send(socket, msg)
  end

  defp process_data(data) do
    RiemannProto.Msg.decode(data)
    |> extract_events
    |> Enum.map(&ensure_timestamp/1)
    |> Enum.map(&stream_event/1)
  end
  
  defp extract_events(%RiemannProto.Msg{events: events}), do: events
  defp extract_events(_), do: []

  defp ensure_timestamp(event = %RiemannProto.Event{time: nil}), do: %{event | time: System.system_time(:seconds)}
  defp ensure_timestamp(event = %RiemannProto.Event{}), do: event
  
  defp stream_event(event) do
    # TODO:
    # - Catch to avoid crash and report errors
    FastTS.Router.Modules.get
    |> Enum.each(fn(module) -> apply(module, :stream, [event]) end)
  end

end

# TODO:
# - Ignore messages with outdated ttl
# - Fix issue with parallel / spawn execution
