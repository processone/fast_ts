defmodule FastTS.Stream.Context do

  @doc """
  Starts a new context agent that will be associated to pipeline block.
  """
  def start_link do
    Agent.start_link(fn -> %{} end)
  end

  @doc """
  Gets a pipeline block value from context for a given key.
  """
  def get(context, key) do
    Agent.get(context, &Map.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key` in the block context.
  """
  def put(context, key, value) do
    Agent.update(context, &Map.put(&1, key, value))
  end

  @doc """
  Clear the block context.
  """
  def clear(context) do
    Agent.update(context, fn _ -> %{} end)
  end

  @doc """
  Get full context as map
  """
  def get_all(context) do
    Agent.get(context, fn state -> state end)
  end
  
end
