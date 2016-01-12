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
    MIX_ENV=prod mix compile

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

    MIX_ENV=prod mix release

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

## Build Docker container 

The following commands will prepare a container to run FastTS:

    mix deps.get
    MIX_ENV=prod mix compile
    MIX_ENV=prod mix release
    docker build -t fast_ts .

You can then run FastTS container on a Docker host with the default
with the default embedded FastTS route file:

    $ docker run --rm -p 5555:5555 fast_ts
    Using /fast_ts/releases/0.0.1/fast_ts.sh
    created directory: '/fast_ts/running-config'
    Exec: /usr/lib/erlang/erts-7.1/bin/erlexec -noshell -noinput +Bd -boot /fast_ts/releases/0.0.1/fast_ts -mode embedded -config /fast_ts/running-config/sys.config -boot_var ERTS_LIB_DIR /usr/lib/erlang/erts-7.1/../lib -env ERL_LIBS /fast_ts/lib -args_file /fast_ts/running-config/vm.args -- foreground
    Root: /fast_ts
    
    18:18:22.875 [info]  Ignoring empty pipeline 'Empty pipeline are ignored'

    18:18:22.879 [info]  Registering Router module: HelloFast.Router

    18:18:22.886 [info]  Accepting connections on port 5555

If you want to start FastTS on Docker with your own route scripts, you
can mount a route directory volume on your Docker host and pass it as
FTS_ROUTE_DIR environment variable:

    docker run -v "$PWD/config/docker":/opt/routes -e "FTS_ROUTE_DIR=/opt/routes" --rm -p 5555:5555 fast_ts

Note: The previous command assume that you are using it from docker
host or that your local Docker Machine as the proper directory
mounted. This is the case for example with Docker Machine on OSX, that
grant access to Docker host to everything under `/Users`. That's why
the previous command should work as is.

## Using the test client with your Docker container

You need IP of your docker machine. If you do not have it, you can get
environment of your docker-machine with:

    $ docker-machine env default
    export DOCKER_TLS_VERIFY="1"
    export DOCKER_HOST="tcp://192.168.99.100:2376"
    export DOCKER_CERT_PATH="/Users/mremond/.docker/machine/machines/default"
    export DOCKER_MACHINE_NAME="default"
    # Run this command to configure your shell:
    # eval "$(docker-machine env default)"

You can this pass the IP addresse of the Docker host (or hostname if
you have any set up) with `riemann-client -H` option:


    $ riemann-client -H 192.168.99.100 send  -h localhost -s web -t latency -t dev -m 120
    {
      "host": "localhost",
      "metric_f": 120.0,
      "service": "web",
      "tags": [
        "latency",
        "dev"
      ]
    }

You should see the following log entry in your attached FastTS Docker container:

    %RiemannProto.Event{attributes: [], description: nil, host: "localhost", metric_d: nil, metric_f: 24.0, metric_sint64: nil, service: "web", state: nil, tags: ["latency", "dev"], time: 1452535525, ttl: nil}


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

## Defining your metrics router

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


