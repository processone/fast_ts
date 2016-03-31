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


  test "changed_state" , %{context: context} do
    {:stateful, cf} = FastTS.Stream.changed_state("ok")
    f = cf.(context, self())
    ev1 = %{create(:event) | service: "s1"}
    ev2 = %{create(:event) | service: "s2"}
    assert nil ==  f.(%{ev1 | state: "ok"})
    assert nil ==  f.(%{ev1 | state: "ok"})
    assert %{ev1 | state: "down"} ==  f.(%{ev1 | state: "down"})
    assert nil ==  f.(%{ev2 | state: "ok"})
    assert nil ==  f.(%{ev1 | state: "down"})
    assert %{ev2 | state: "down"} ==  f.(%{ev2 | state: "down"})
    assert %{ev2 | state: "ok"} ==  f.(%{ev2 | state: "ok"})
    assert nil ==  f.(%{ev2 | state: "ok"})
    assert nil ==  f.(%{ev1 | state: "down"})
  end

  test "general change detector" , %{context: context} do
    {:stateful, cf} = FastTS.Stream.changed(fn %Event{metric_f: n} -> n end, 0, fn _ -> :some end) #just group all in together
    f = cf.(context, self())
    ev1 = %{create(:event) | service: "s1"}
    ev2 = %{create(:event) | service: "s2"}
    assert nil ==  f.(%{ev1 | metric_f: 0})
    assert nil ==  f.(%{ev2 | metric_f: 0})
    assert %{ev1 | metric_f: 1} ==  f.(%{ev1 | metric_f: 1})
    assert nil ==  f.(%{ev2 | metric_f: 1})
    assert %{ev2 | metric_f: 2} ==  f.(%{ev2 | metric_f: 2})
  end


  test "consecutive runs", %{context: context} do
    {:stateful, cf} = FastTS.Stream.runs(3, fn %Event{state: s} -> s end)
    f = cf.(context, self())
    ev = create(:event)
    assert nil == f.(%{ev | state: "ok"})
    assert nil == f.(%{ev | state: "ok"})
    assert %{ev | state: "ok"} == f.(%{ev | state: "ok"})
    assert %{ev | state: "ok"} == f.(%{ev | state: "ok"})
    assert nil == f.(%{ev | state: "down"})
    assert nil == f.(%{ev | state: "ok"})
    assert nil == f.(%{ev | state: "down"})
    assert nil == f.(%{ev | state: "down"})
    assert %{ev | state: "down"} == f.(%{ev | state: "down"})
    assert %{ev | state: "down"} == f.(%{ev | state: "down"})
  end

  #TODO: see how to mock time/timeouts



  #pass N blocks  "do" block and "else" block
  #para continuar, el stateful le pasa el key del block al que tiene que seguir invocando

	test "rate2", %{context: context} do
		{:flowop, f, state, [:mt], kv_downstream}  = FastTS.Stream.rate2 1, do: nil
		ev = %{create(:event) | metric_f: 1}
		ts = System.monotonic_time(:milli_seconds)
		assert {state, [], 1000}  = f.(state, ev, mt: ts)
		assert {state, [], 500}  = f.(state, ev, mt: ts + 500)
		expected = %{ev | metric_f: 2.0}
		assert {state, [do: ^expected], 1000} = 
								f.(state, :timeout, mt: ts + 1000)
		assert {state, [], 500} = f.(state, ev, mt: ts + 1500)
		assert {state, [], 400} = f.(state, ev, mt: ts + 1600)
		assert {state, [], 400} = f.(state, ev, mt: ts + 1600)
		expected = %{ev | metric_f: 3.0}
		assert {state, [do: ^expected], 1000} = 
			f.(state, :timeout, mt: ts + 2000)
	end

end
