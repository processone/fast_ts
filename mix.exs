defmodule FastTS.Mixfile do
  use Mix.Project

  def project do
    [app: :fast_ts,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(Mix.env)]
  end

  def application do
    [applications: [:logger, :exprotobuf, :gpb],
     mod: {FastTS, []}
    ]
  end

  defp deps(:prod) do
    [{:exprotobuf, "~> 0.11.0"},
     {:mailman, "~> 0.2.2"},
     #     {:mailman, "~> 0.2.1"},
     # {:mailman, git: "/Users/mremond/tmp/mailman", branch: "mailman_mix_config"},
     {:exrm, "~> 1.0.0-rc7"}]
  end
  
  defp deps(_) do
    deps(:prod) ++
      [{:dialyze, "~> 0.2.0"},
       {:eqc_ex, "~> 1.2.3"}
      ]
  end
end
