defmodule Hydra do
  @moduledoc """
  Documentation for `Hydra`.
  """

  def parse(nil), do: raise("You must provide a spec URL or file path")

  def parse("https://" <> _ = url) do
    IO.inspect(url, label: "Parsing URL")
    spec = Req.get!(url).body
    Hydra.Spec.parse(spec)
  end

  def parse(file) do
    IO.inspect(file, label: "Parsing file")

    File.read!(file)
    |> JSON.decode!()
    |> Hydra.Spec.parse()
  end
end
