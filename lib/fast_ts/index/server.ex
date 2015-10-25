defmodule FastTSIndexServer do
  @doc """
  Create a new index.
  """
  def start_link do
    Agent.start_link(fn -> HashDict.new end)
  end

  @doc """
  Gets a value from the `index` by `key`.
  """
  def get(index, key) do
    Agent.get(index, &HashDict.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key` in the `index`.
  """
  def put(index, key, value) do
    Agent.update(index, &HashDict.put(&1, key, value))
  end
end
