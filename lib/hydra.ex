defmodule Hydra do
  @moduledoc """
  Documentation for `Hydra`.
  """

  def parse(nil), do: raise("You must provide a spec URL or file path")

  def parse("https://" <> _ = url) do
    spec = Req.get!(url).body
    Hydra.Spec.parse(spec)
  end

  def parse(file) do
    File.read!(file)
    |> Jason.decode!()
    |> Hydra.Spec.parse()
  end
end
