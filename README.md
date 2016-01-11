# FastTS

FastTS is a fast Time Series Event Stream Processor.

It is designed with two major use cases in mind:

- Cloud platforms: coordination and monitoring of complex and large server infrastructure,
- Internet of Things: monitor and control large machine network.

FastTS is designed to be highly versatile and scalable.
It is a framework: the platform is configurable with a high-level
Elixir-base Domain Specific Language.

The project is inspired by ideas introduced by Phoenix Framework and
Riemann.

The current version design has one process per pipeline step and pass
data down the pipeline through message passing. Riemann use function
calls between pipeline steps. We may offer such a option in a next
version.

## Usage

### Prerequite

Erlang R18+ and Elixir 1.1+.

### Building FastTS

Here is how to build, prepare a first metrics routing script and deploy the tool:

You can first checkout FastTS from Github:

    git clone https://github.com/processone/fast_ts.git
   
Download dependencies and compile the project:
   
    mix deps.get
    mix compile

You can then tweak the file in config directory. Most notably you can
tweak the example time series route example file: `config/route.exs`

You can then start the project with console attached with:

    iex -S mix

### Injecting metrics with Riemann client

You can test injecting data with the Riemann protocol.

You can for example try [Riemann Python client](https://github.com/borntyping/python-riemann-client):

    riemann-client send -h localhost -s web  -t latency -t dev -m 120

In that example:
- host (-h) is `localhost`
- service (-s) is `web`
- tags (-t) are `latency` and `dev`
- metric (-m) value is 120

If you are using the default example route script, you should see in
log file events printed to STDOUT:

    %RiemannProto.Event{attributes: [], description: nil, host: "localhost", metric_d: nil, metric_f: 4.0, metric_sint64: nil, service: "web", state: nil, tags: ["latency", "dev"], time: 1452510805, ttl: nil}

## Release / deployment

For deployment, you can then prepare a release directory:

    mix release

You can then test your release locally. Go to release dir:

    cd rel/fast_ts

You can create a directory to store your route scripts:

    mkdir routes

and then create your own time series route file: `routes/route.exs`

When done you can start your release, for example with console attached:

    FTS_ROUTE_DIR=routes bin/fast_ts console

`FTS_ROUTE_DIR` environment variable allows you to configure route
scripts directory.

For deploy you can simply compress the whole rel/ directory and
uncompress it on server. It contains all needed code, including Erlang
VM and Elixir environment.

## Embbed FastTS in your own app

Embedding FastTS into your app will allow you to have your own metrics
/ alert dispatcher included into your system.

  1. Add fast_ts to your list of dependencies in `mix.exs`:

        def deps do
          [{:fast_ts,  github: "processone/fast_ts"}]
        end

  2. Ensure fast_ts is started before your application:

        def application do
          [applications: [:fast_ts]]
        end

## Defining your metrics / time series routes

Here is an example file showing a basic FastTS route script:

    defmodule HelloFast.Router do
      use FastTS.Router
    
      pipeline "Basic pipeline" do
        # We only take functions under a given value
        under(12)
        stdout
      end
      
      pipeline "Second pipeline" do
        # Buffer event for 5 second and calcule the rate of accumulate events per second
        rate(5)
        stdout
      end
    
      pipeline "Empty pipeline are ignored" do
      end
      
    end


