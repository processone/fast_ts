defmodule FastTS.Router do
  defmacro __using__(_options) do
    quote do
      alias RiemannProto.Event
      alias FastTS.Stream

      # Needed to be able to inject pipeline macro in the module using FastTS.Router:
      import unquote(__MODULE__)
      
      # Define pipelines module attribute as accumulator:
      Module.register_attribute __MODULE__, :pipelines, accumulate: true

      # Delay the generation of some method to a last pass to allow getting the full result of the pipeline
      # accumulation (it will be done in macro __before_compile__/1
      @before_compile unquote(__MODULE__)
    end
  end

  # list_pipelines is now defined and print the correct list of defined pipelines when called:
  # iex(1)> HelloFast.Router.list_pipelines
  # Defined pipelines in the router: [:"Second pipeline", :"Calculate Rate and Broadcast"]
  # :ok
  defmacro __before_compile__(_env) do
    quote do
      def list_pipelines do
        IO.puts "Defined pipelines in the router: #{inspect @pipelines}"
      end
    end
  end
  
  defmacro pipeline(description, do: pipeline_block) do
    pipeline_name = String.to_atom(description)
    quote do
      @pipelines unquote(pipeline_name)
      def unquote(pipeline_name)(), do: unquote(pipeline_block)
    end
  end

end
