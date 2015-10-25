defmodule RiemannProto do
  use Protobuf, from: Path.expand("riemann.proto", __DIR__)
end

# TODO: can we define a shorter name ?
