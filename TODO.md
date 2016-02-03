# Multiple format

To have a generic streaming tool, we need to support multiple format:

* Metrics: We support the Riemann format for metrics.
* Message: We support the Node Red format for messages.

Some blocks can handle both, other type of blocks will just drop the
content of unknown "packet" types.

# Improvement for Elixir protobuf support

```
iex(6)> new = RiemannProto.Event.new
%RiemannProto.Event{attributes: [], description: nil, host: nil, metric_d: nil,
 metric_f: nil, metric_sint64: nil, service: nil, state: nil, tags: [],
 time: nil, ttl: nil}
iex(7)> new[:attributes]
** (UndefinedFunctionError) undefined function: RiemannProto.Event.fetch/2
    (fast_core) RiemannProto.Event.fetch(%RiemannProto.Event{attributes: [], description: nil, host: nil, metric_d: nil, metric_f: nil, metric_sint64: nil, service: nil, state: nil, tags: [], time: nil, ttl: nil}, :attributes)
    (elixir) lib/access.ex:72: Access.get/3
```

We need the generated proto beam to support fetch to have a nice getter syntax.
