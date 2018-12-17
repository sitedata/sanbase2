defmodule SanbaseWeb.Graphql.Resolvers.GithubResolver do
  require Logger

  alias SanbaseWeb.Graphql.Helpers.Utils
  alias Sanbase.Model.Project
  alias Sanbase.Github.Store

  def dev_activity(
        _root,
        %{
          slug: slug,
          from: from,
          to: to,
          interval: interval,
          transform: transform,
          moving_average_interval_base: moving_average_interval_base
        },
        _resolution
      ) do
    with {:ok, github_organization} <- Project.github_organization(slug),
         {:ok, result} <-
           Sanbase.Clickhouse.Github.dev_activity(
             github_organization,
             from,
             to,
             interval,
             transform,
             moving_average_interval_base
           ) do
      {:ok, result}
    else
      {:error, {:github_link_error, error}} ->
        {:ok, []}

      error ->
        Logger.error("Cannot fetch github activity for #{slug}. Reason: #{inspect(error)}")
        {:error, "Cannot fetch github activity for #{slug}"}
    end
  end

  def github_activity(root, %{ticker: ticker} = args, resolution) do
    %Project{coinmarketcap_id: slug} = Project.slug_by_ticker(ticker)
    args = args |> Map.delete(:ticker) |> Map.put(:slug, slug)
    github_activity(root, args, resolution)
  end

  def github_activity(
        _root,
        %{
          slug: slug,
          from: from,
          to: to,
          interval: interval,
          transform: transform,
          moving_average_interval_base: moving_average_interval_base
        },
        _resolution
      ) do
    with {:ok, github_organization} <- Project.github_organization(slug),
         {:ok, from, to, interval} <-
           Utils.calibrate_interval(
             Sanbase.Clickhouse.Github,
             github_organization,
             from,
             to,
             interval,
             24 * 60 * 60
           ),
         {:ok, result} <-
           Sanbase.Clickhouse.Github.github_activity(
             github_organization,
             from,
             to,
             interval,
             transform,
             moving_average_interval_base
           ) do
      {:ok, result}
    else
      {:error, {:github_link_error, error}} ->
        {:ok, []}

      error ->
        Logger.error("Cannot fetch github activity for #{slug}. Reason: #{inspect(error)}")
        {:error, "Cannot fetch github activity for #{slug}"}
    end
  end

  def activity(root, %{slug: slug} = args, resolution) do
    # Temporary solution while all frontend queries migrate to using slug. After that
    # only the slug query will remain
    if ticker = Project.ticker_by_slug(slug) do
      args = args |> Map.delete(:slug) |> Map.put(:ticker, ticker)
      activity(root, args, resolution)
    else
      {:ok, []}
    end
  end

  def activity(
        _root,
        %{ticker: ticker, from: from, to: to, interval: interval, transform: "None"},
        _resolution
      ) do
    ticker = correct_ticker(ticker)

    {:ok, from, to, interval} =
      Utils.calibrate_interval(Store, ticker, from, to, interval, 24 * 60 * 60)

    result =
      Store.fetch_activity_with_resolution!(ticker, from, to, interval)
      |> Enum.map(fn {datetime, activity} -> %{datetime: datetime, activity: activity} end)

    {:ok, result}
  end

  def activity(
        _root,
        %{
          ticker: ticker,
          from: from,
          to: to,
          interval: interval,
          transform: "movingAverage",
          moving_average_interval_base: ma_base
        },
        _resolution
      ) do
    ticker = correct_ticker(ticker)

    {:ok, from, to, interval, ma_interval} =
      Utils.calibrate_interval_with_ma_interval(
        Store,
        ticker,
        from,
        to,
        interval,
        24 * 60 * 60,
        ma_base,
        300
      )

    result =
      Store.fetch_moving_average_for_hours!(ticker, from, to, interval, ma_interval)
      |> Enum.map(fn {datetime, activity} -> %{datetime: datetime, activity: activity} end)

    {:ok, result}
  end

  def available_repos(_root, _args, _resolution) do
    # returns {:ok, result} | {:error, error}
    Store.list_measurements()
  end

  defp correct_ticker("MKR"), do: "DAI"
  defp correct_ticker("DGX"), do: "DGD"
  defp correct_ticker(ticker), do: ticker
end
