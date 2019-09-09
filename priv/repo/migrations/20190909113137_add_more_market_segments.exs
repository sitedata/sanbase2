defmodule Sanbase.Repo.Migrations.AddMoreMarketSegments do
  use Ecto.Migration

  import Ecto.Query

  alias Sanbase.Model.{Project, MarketSegment}

  def up do
    setup()

    projects = get_projects()

    infrastrucutre_to_segment_id = infrastrucutre_to_segment_id(projects)

    insert_data =
      projects
      |> Enum.map(fn
        %{id: id, infrastructure: %{code: code}} when not is_nil(code) ->
          %{
            project_id: id,
            market_segment_id: Map.get(infrastrucutre_to_segment_id, code)
          }

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    Sanbase.Repo.insert_all(Project.ProjectMarketSegment, insert_data)
  end

  def down, do: :ok

  defp get_projects() do
    Project.List.projects() |> Sanbase.Repo.preload([:infrastructure, :market_segments])
  end

  defp infrastrucutre_to_segment_id(projects) do
    infrastrucutre_to_segment =
      Enum.zip(
        ~w(BTC EOS ETC ETH IOTA NEO NXT OMNI UBQ WAVES XCP XEM),
        ~w(Bitcoin EOS Ethereum-Classic Ethereum IOTA Neo Nxt Omni Ubiq Waves Counterparty NEM)
      )
      |> Map.new()

    infrastrucutre_to_segment =
      ~w(Achain Ardor Binance Bitshares Graphene Komodo Nebulas Qtum Scrypt Steem Stellar Tron)
      |> Enum.reduce(infrastrucutre_to_segment, fn name, acc ->
        Map.put(acc, name, name)
      end)

    market_segment_names = infrastrucutre_to_segment |> Map.values()

    insert_data =
      market_segment_names
      |> Enum.map(fn segment -> %{name: segment} end)

    Sanbase.Repo.insert_all(MarketSegment, insert_data, on_conflict: :nothing)

    market_segments =
      from(ms in MarketSegment, where: ms.name in ^market_segment_names) |> Sanbase.Repo.all()

    infrastrucutre_to_segment
    |> Enum.map(fn {k, v} ->
      segment = Enum.find(market_segments, fn %{name: name} -> name == k || name == v end)
      {k, segment.id}
    end)
    |> Map.new()
  end

  defp names_by_ticker(tickers) do
    Project.List.by_field(tickers, :ticker) |> Enum.map(& &1.name)
  end

  defp setup() do
    Application.ensure_all_started(:tzdata)
    Application.ensure_all_started(:prometheus_ecto)
    Sanbase.Prometheus.EctoInstrumenter.setup()
  end
end
