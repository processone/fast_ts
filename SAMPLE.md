** Work in progress **

Filter events that are "down".  Of those, split in two, one for "critical" service and the other for the rest.
If it is "critical"  print it two times (note: that's not sequencial, it is two separate streams to where the event is sent,
here just for testing both strams are simple a print)
If it is not critical, count the number of occurrences over 10 seconds interval.  If the rate of ocurrences per second during
an interval is greater than 1/sec,  print it.

```
    pipeline = 
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

    p = Filter.start(pipeline)   
    Enum.each (1..100), fn _ -> send(p, %Event{metric_f: 11, state: "down", service: "non_critical"}) end  
```


