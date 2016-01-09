defmodule FastTS.Router do
  defmacro __using__(_options) do
    quote do
      alias RiemannProto.Event
      alias FastTS.Stream
    end
  end
end
