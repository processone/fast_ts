defmodule FastTS.Stream.ContextTest do
  use ExUnit.Case, async: true
  alias FastTS.Stream.Context

  test "stores values by key in context" do
    {:ok, context} = Context.start_link
    assert Context.get(context, "key1") == nil

    Context.put(context, "key1", 3)
    assert Context.get(context, "key1") == 3
  end

  test "can clear context" do
    {:ok, context} = Context.start_link
    assert Context.get(context, "key1") == nil

    Context.put(context, "key1", 3)
    assert Context.get(context, "key1") == 3

    Context.clear(context)
    assert Context.get(context, "key1") == nil
  end
end
