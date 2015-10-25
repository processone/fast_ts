# Fast TS

Fast TS is a fast Time Series Event Stream Processor.

It is designed with two major use cases in mind:

- Cloud platforms: coordination and monitoring of complex and large server infrastructure,
- Internet of Things: monitor and control large macha

Fast TS is designed to be highly versatile and scalable.
It is a framework: the platform is configurable with a high-level Elixir-base Domain Specific Language.

The project is inspired by ideas introduced by Phoenix Framework and Riemann.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add fast_core to your list of dependencies in `mix.exs`:

        def deps do
          [{:fast_ts, "~> 0.0.1"}]
        end

  2. Ensure fast_core is started before your application:

        def application do
          [applications: [:fast_ts]]
        end

## Test client

You can test injecting data with the Riemann protocol.

You can for example try Riemann Python client:

    riemann-client send -h localhost -s test -t test -t test2
