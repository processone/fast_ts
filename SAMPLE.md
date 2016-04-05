** Work in progress **

See filter.ex  test_pipeline for some sample one that show more advanced sharing and pipeline construction.
Can be run with
iex -S mix
> FastTS.Stream.Filter.test_pipeline()


Two sample pipelines.

pipeline1:
count # events /sec ,  per host. So will emit things like  {host1, 2}  {host2, 5}   , etc.

pipeline2:
Filter events that are "down".  Of those, split in two, one for "critical" service and the other for the rest.
If it is "critical"  print it two times (note: that's not sequencial, it is two separate streams to where the event is sent,
here just for testing both strams are simple a print)
If it is not critical, count the number of occurrences over 10 seconds interval.  If the rate of ocurrences per second during
an interval is greater than 1/sec,  print it.

```
    alias RiemannProto.Event
    alias FastTS.Stream.Filter
    import FastTS.Stream

    # Just count event/sec per host. 
    pipeline1 = by(fn %Event{host: h} -> h end) do
                  map2(fn ev ->%{ev | metric_f: 1} end) do
                    rate2(1, do: print2)
                  end
                end

    pipeline2 = 
      filter2(fn %Event{state: "down"} -> true end) do
	      split(fn %Event{service: "critical"} -> true end) do
		  	  [
          print2,
          print2
          ]
		    else
	    	  map2(fn ev ->%{ev | metric_f: 1} end) do
		        rate2(10) do
			       over2(1, do: print2)
		        end
		      end
        end
      end

    p1 = Filter.start(pipeline1)   
    p2 = Filter.start(pipeline2)   
    pipelines = [p1,p2]
    emit = fn ev -> Enum.each pipelines, &(send(&1, ev)) end
    Enum.each (1..100), fn _ -> emit.(%Event{metric_f: 11, state: "down", service: "non_critical"}) end  
```


