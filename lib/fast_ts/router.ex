defmodule FastTS.Router do

  defmacro __using__(_options) do
    quote do
      alias RiemannProto.Event
      alias FastTS.Stream

      # Needed to be able to inject pipeline macro in the module using FastTS.Router:
      import unquote(__MODULE__), only: [pipeline: 2]
      
      # Define pipelines module attribute as accumulator:
      Module.register_attribute __MODULE__, :pipelines, accumulate: true

      # Delay the generation of some method to a last pass to allow getting the full result of the pipeline
      # accumulation (it will be done in macro __before_compile__/1
      @before_compile unquote(__MODULE__)

      FastTS.Router.register_router(__MODULE__)
    end
  end

  # list_pipelines is added to module and print the correct list of defined pipelines when called
  defmacro __before_compile__(_env) do
    quote do

      
      def list_pipelines do
        IO.puts "Defined pipelines in the router: #{inspect @pipelines}"
      end

      def streams do
        Enum.map(@pipelines,
          fn(name) ->
            {name, apply(__MODULE__, name, [])}
          end)
      end

      def stream(event) do
        streams |>
          Enum.each( fn({name, _pipeline}) -> send(name, event) end)
      end

    end
  end

  # To make sure, we generate properly the pipeline, a pipeline can
  # only use a sequence of operation defined in the stream API
  defmacro pipeline(description, do: pipeline_block) do
    pipeline_name = String.to_atom(description)
    
    # Transform the block call in a list of function calls
    block = case pipeline_block do
              nil ->
                nil
              {:__block__, [], block_sequence} ->
                block_sequence
              single_op ->
                [single_op]
            end

    case block do
      #
      nil ->
        IO.puts "Ignoring empty pipeline '#{description}'"
      _ ->
        quote do
          @pipelines unquote(pipeline_name)
          def unquote(pipeline_name)(), do: unquote(block)
        end
    end
  end

  def register_router(module) do
    IO.puts "Registering Router module: #{inspect module}"
    FastTS.Router.Modules.register(module)
  end
  
end
