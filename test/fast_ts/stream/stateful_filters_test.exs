#{:stateful, f}
defmodule StatefulFiltersTest do
  use ExUnit.Case, async: true
  alias RiemannProto.Event
  import FastTSTestHelper

  doctest FastTS

  setup do
    {:ok, context} = FastTS.Stream.Context.start_link
    {:ok, context: context}
  end

  test "sreduce with initial value", %{context: context} do
      {:stateful, cf} = FastTS.Stream.sreduce(fn prev, %Event{metric_f: n} -> prev + n end, 0)
      f = cf.(context, self())
      assert 1 == f.(%{create(:event) | metric_f: 1})
      assert 5 == f.(%{create(:event) | metric_f: 4})
      assert 5 == f.(%{create(:event) | metric_f: 0})
  end

  test "sreduce producing events, no initial value", %{context: context} do
      {:stateful, cf} = FastTS.Stream.sreduce(fn %Event{metric_f: n1}, %Event{metric_f: n}=e -> %{e | metric_f: max(n1, n)} end)
      f = cf.(context, self())
      ev = create(:event)
      assert nil == f.(%{ev | metric_f: 1}) #first event is used to start the accumulator if not provided, it is not propagated. Same as riemann
      assert %{ev | metric_f: 4} == f.(%{ev | metric_f: 4})
      assert %{ev | metric_f: 4} == f.(%{ev | metric_f: 2})
      assert %{ev | metric_f: 6} == f.(%{ev | metric_f: 6})
      assert %{ev | metric_f: 6} == f.(%{ev | metric_f: 4})
  end

  test "sreduce producing events, initial value", %{context: context} do
      {:stateful, cf} = FastTS.Stream.sreduce(fn %Event{metric_f: n1}, %Event{metric_f: n}=e -> 
                          %{e | metric_f: max(n1, n)} end, %{create(:event) | metric_f: 4})
      f = cf.(context, self())
      ev = create(:event)
      assert %{ev | metric_f: 4} == f.(%{ev | metric_f: 1})
      assert %{ev | metric_f: 5} == f.(%{ev | metric_f: 5})
      assert %{ev | metric_f: 5} == f.(%{ev | metric_f: 2})
      assert %{ev | metric_f: 6} == f.(%{ev | metric_f: 6})
      assert %{ev | metric_f: 6} == f.(%{ev | metric_f: 4})
  end


end
