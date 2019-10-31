defmodule Sanbase.Kafka.Topic.ExchangeMarketDepth do
  @topic "exchange_market_depth"
  defstruct [
    :source,
    :symbol,
    :timestamp,
    :ask,
    :asks025_percent_depth,
    :asks025_percent_volume,
    :asks05_percent_depth,
    :asks05_percent_volume,
    :asks075_percent_depth,
    :asks075_percent_volume,
    :asks10_percent_depth,
    :asks10_percent_volume,
    :asks1_percent_depth,
    :asks1_percent_volume,
    :asks20_percent_depth,
    :asks20_percent_volume,
    :asks2_percent_depth,
    :asks2_percent_volume,
    :asks30_percent_depth,
    :asks30_percent_volume,
    :asks5_percent_depth,
    :asks5_percent_volume,
    :bid,
    :bids025_percent_depth,
    :bids025_percent_volume,
    :bids05_percent_depth,
    :bids05_percent_volume,
    :bids075_percent_depth,
    :bids075_percent_volume,
    :bids10_percent_depth,
    :bids10_percent_volume,
    :bids1_percent_depth,
    :bids1_percent_volume,
    :bids20_percent_depth,
    :bids20_percent_volume,
    :bids2_percent_depth,
    :bids2_percent_volume,
    :bids30_percent_depth,
    :bids30_percent_volume,
    :bids5_percent_depth,
    :bids5_percent_volume
  ]

  def format_message(message_map) do
    message_map
    |> Enum.map(fn {k, v} -> {Regex.replace(~r/_(\d+)/, k, "\\1"), v} end)
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
    |> Enum.into(%{})
    |> format_timestamp()
  end

  defp format_timestamp(%{timestamp: timestamp} = exchange_market_depth) do
    %{exchange_market_depth | timestamp: DateTime.from_unix!(floor(timestamp), :millisecond)}
  end
end