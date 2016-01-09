defmodule FastTS.Router do
  defmacro __using__(_options) do
    quote do
      alias RiemannProto.Event
      alias FastTS.Stream

      # Needed to be able to inject pipeline macro in the module using FastTS.Router:
      import unquote(__MODULE__)      
    end
  end

  defmacro pipeline(description, do: pipeline_block) do
    pipeline_name = String.to_atom(description)
    quote do
      def unquote(pipeline_name)(), do: unquote(pipeline_block)
    end
  end

end
