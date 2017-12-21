defmodule Sanbase.ExternalServices.TwitterData.HistoricalData do
  @moduledoc ~S"""
    Polls twittercounter.com for account data and stores it in
    a time series database.
  """

  use Tesla
  use GenServer, restart: :permanent, shutdown: 5_000

  plug(Tesla.Middleware.BaseUrl, "http://api.twittercounter.com/")
  plug(Tesla.Middleware.Logger)

  @rate_limiter_name :twittercounter_api_rate_limiter

  require Logger

  import Ecto.Query
  import Sanbase.Utils, only: [parse_config_value: 1]

  alias Sanbase.Repo
  alias Sanbase.Model.Project
  alias Sanbase.Influxdb.Measurement
  alias Sanbase.ExternalServices.RateLimiting
  alias Sanbase.ExternalServices.TwitterData.{HistoricalData, Store}

  @default_update_interval 1000 * 60 * 60 * 24 # 1 day

  def start_link(_state) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    if get_config(:sync_enabled, false) do
      Store.create_db()
      update_interval_ms = get_config(:update_interval, @default_update_interval)

      GenServer.cast(self(), :sync)
      {:ok, %{update_interval_ms: update_interval_ms}}
    else
      :ignore
    end
  end

  def handle_cast(:sync, %{update_interval_ms: update_interval_ms} = state) do
    query =
      from(
        p in Project,
        select: p.twitter_link,
        where: not is_nil(p.twitter_link)
      )

    Task.Supervisor.async_stream_nolink(
      Sanbase.TaskSupervisor,
      Repo.all(query),
      &fetch_and_store/1,
      ordered: false,
      max_concurency: System.schedulers_online() * 2,
      timeout: 1000 * 60 * 60
    )
    |> Stream.run()

    Process.send_after(self(), {:"$gen_cast", :sync}, update_interval_ms)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.msg("Unknown message received: #{msg}")
    {:noreply, state}
  end

  defp fetch_and_store("https://twitter.com/" <> twitter_name) do
    # Ignore trailing slash and everything after it
    twitter_name = String.split(twitter_name, "/") |> hd

    # Twittercounter works only with id, but not with name
    %ExTwitter.Model.User{id: twitter_id, id_str: twitter_id_str} =
      twitter_name
      |> Sanbase.ExternalServices.TwitterData.Worker.fetch_twitter_user_data()

    case has_scraped_data?(twitter_name) do
      false ->
        {twitter_id, twitter_id_str}
        |> fetch_twittercounter_user_data()
        |> convert_to_measurement(twitter_name)
        |> store_twitter_user_data()
      true ->
        :ok
    end
  end

  defp fetch_and_store(args) do
    Logger.warn("Invalid parameters while fetching twitter data: " <> inspect(args))
  end

  defp fetch_twittercounter_user_data({twitter_id, twitter_id_str}) do
    RateLimiting.Server.wait(@rate_limiter_name)

    apikey = get_config(:apikey, "")

    case get("/?twitter_id=" <> twitter_id_str <> "&apikey=" <> apikey) do
      %Tesla.Env{status: 200, body: body} ->
        body
        |> Poison.decode!()
        |> Map.get("followersperdate")

      %Tesla.Env{status: 401} ->
        Logger.warn("Twittercounter API credentials are missing or incorrect")

      %Tesla.Env{status: 403} ->
        Logger.info("Twittercounter API limit has been reached")
    end
  end

  defp store_twitter_user_data([]), do: :ok

  defp store_twitter_user_data(user_data_measurement) do
    user_data_measurement
    |> Store.import()
  end

  defp has_scraped_data?(twitter_name) do
    nil != Store.last_record_with_tag_value(twitter_name, :source, "twittercounter")
  end

  defp convert_to_measurement(
         user_data,
         measurement_name
       ) do
    user_data
    |> Enum.map(fn {datetime, followers_count} ->
         %Measurement{
           timestamp: from_twittercounter_date(datetime),
           fields: %{followers_count: followers_count},
           tags: [source: "twittercounter"],
           name: measurement_name
         }
       end)
  end

  defp get_config(key, default \\ nil) do
    Application.fetch_env!(:sanbase, __MODULE__)
    |> Keyword.get(key, default)
    |> parse_config_value()
  end

  defp from_twittercounter_date("date" <> date) do
    Timex.parse!(date, "{YYYY}-{0M}-{0D}")
    |> Timex.to_datetime()
    |> DateTime.to_unix(:nanosecond)
  end
end