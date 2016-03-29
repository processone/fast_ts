defmodule StatelessFiltersTest do
  use ExUnit.Case
  alias RiemannProto.Event
  import FastTSTestHelper

  doctest FastTS

  test "under" do
    {:stateless, f} = FastTS.Stream.under(2)
    ev3 = %{create(:event) | metric_f: 3}
    ev2 = %{create(:event) | metric_f: 2}
    ev0 = %{create(:event) | metric_f: 0}
    assert ev0 == f.(ev0)
    assert nil == f.(ev2)
    assert nil == f.(ev3)
  end

  test "over" do
    {:stateless, f} = FastTS.Stream.over(2)
    ev3 = %{create(:event) | metric_f: 3}
    ev2 = %{create(:event) | metric_f: 2}
    ev0 = %{create(:event) | metric_f: 0}
    assert nil == f.(ev0)
    assert nil == f.(ev2)
    assert ev3 == f.(ev3)
  end

  test "scale" do
    {:stateless, f} = FastTS.Stream.scale(2)
    ev2 = %{create(:event) | metric_f: 2}
    ev0 = %{create(:event) | metric_f: 0}
    assert %{ev2 | metric_f: 4} == f.(ev2)
    assert ev0 == f.(ev0)
  end

  test "filter" do
    ev = %{create(:event) | metric_f: 1, state: "ok"}
    
    # Function clause exceptions are handled as false 
    {:stateless, down} = FastTS.Stream.filter(fn %Event{state: "down"} -> true end)
    assert nil == down.(ev)

    {:stateless, up} = FastTS.Stream.filter(fn %Event{state: "ok"} -> true end)
    assert ev == up.(ev)

    {:stateless, down} = FastTS.Stream.filter(fn %Event{state: "down"} -> true end)
    assert nil == down.(ev)
  end

  test "map" do
    ev = %{create(:event) | metric_f: 1, state: "ok"}
    {:stateless, m} = FastTS.Stream.map(fn ev -> %{ev | state: "down"} end)
    assert %{ev | state: "down"} == m.(ev)
  end

  test "tag" do
    ev = %{create(:event) | tags: []}
    {:stateless, t} = FastTS.Stream.tag("tag1")
    assert %{ev | tags: ["tag1"]} ==  t.(ev) 
    {:stateless, t} = FastTS.Stream.tag(["tag1", "tag2"])
    assert %{ev | tags: ["tag1", "tag2"]} ==  t.(ev) 

    ev = %{create(:event) | tags: ["tag1"]}
    {:stateless, t} = FastTS.Stream.tag("tag1")
    assert ev ==  t.(ev) 
    {:stateless, t} = FastTS.Stream.tag("tag2")
    assert %{ev | tags: ["tag1", "tag2"]} ==  t.(ev) 
  end

  test "tagged_all" do
    ev = %{create(:event) | tags: []}
    ev1 = %{create(:event) | tags: ["tag1"]}
    ev2 = %{create(:event) | tags: ["tag1", "tag2", "tag3"]}
    {:stateless, t} = FastTS.Stream.tagged_all("tag1")
    assert nil ==  t.(ev) 
    assert ev1 ==  t.(ev1) 
    assert ev2 ==  t.(ev2) 
    {:stateless, t} = FastTS.Stream.tagged_all(["tag1", "tag3"])
    assert nil ==  t.(ev) 
    assert nil ==  t.(ev1) 
    assert ev2 ==  t.(ev2) 
  end

  test "tagged_any" do
    ev = %{create(:event) | tags: []}
    ev1 = %{create(:event) | tags: ["tag1"]}
    ev2 = %{create(:event) | tags: ["tag1", "tag2", "tag3"]}
    {:stateless, t} = FastTS.Stream.tagged_any("tag1")
    assert nil ==  t.(ev) 
    assert ev1 ==  t.(ev1) 
    assert ev2 ==  t.(ev2) 
    {:stateless, t} = FastTS.Stream.tagged_any(["tag1", "tag3"])
    assert nil ==  t.(ev) 
    assert ev1 ==  t.(ev1) 
    assert ev2 ==  t.(ev2) 
  end
end
