defmodule Sanbase.Signal.Trigger.WalletTriggerSettings do
  @moduledoc ~s"""
  The wallet signal is triggered when the balance of a wallet or set of wallets
  changes by a predefined amount for a specified asset (Ethereum, SAN tokens, Bitcoin, etc.)

  The signal can follow a single address, a list of addresses
  or a project. When a list of addresses or a project is followed, all the addresses
  are considered to be owned by a single entity and the transfers between them
  are excluded.
  """

  use Vex.Struct

  import Sanbase.{Validation, Signal.Validation}
  import Sanbase.DateTimeUtils, only: [round_datetime: 2, str_to_sec: 1]

  alias __MODULE__
  alias Sanbase.Model.Project
  alias Sanbase.Signal.Type

  @derive {Jason.Encoder, except: [:filtered_target, :triggered?, :payload, :template_kv]}
  @trigger_type "wallet_movement"

  @enforce_keys [:type, :channel, :target, :asset]
  defstruct type: @trigger_type,
            channel: nil,
            selector: nil,
            target: nil,
            operation: nil,
            time_window: "1d",
            # Private fields, not stored in DB.
            filtered_target: %{list: []},
            triggered?: false,
            payload: %{},
            template_kv: %{}

  @type t :: %__MODULE__{
          type: Type.trigger_type(),
          channel: Type.channel(),
          target: Type.complex_target(),
          selector: map(),
          operation: Type.operation(),
          time_window: Type.time_window(),
          # Private fields, not stored in DB.
          filtered_target: Type.filtered_target(),
          triggered?: boolean(),
          payload: Type.payload(),
          template_kv: Type.template_kv()
        }

  validates(:channel, &valid_notification_channel?/1)
  validates(:target, &valid_crypto_address?/1)
  validates(:selector, &valid_historical_balance_selector?/1)
  validates(:operation, &valid_operation?/1)
  validates(:time_window, &valid_time_window?/1)

  @spec type() :: String.t()
  def type(), do: @trigger_type

  @doc ~s"""
  Return a list of the `settings.metric` values for the necessary time range
  """
  def get_data(
        %__MODULE__{
          filtered_target: %{list: target_list, type: :address},
          selector: selector
        } = settings
      ) do
    {from, to} = get_timeseries_params(settings)

    target_list
    |> Enum.map(fn address ->
      with {:ok, [{address, {balance_before, balance_after, _balance_change}}]} <-
             balance_change(selector, address, from, to) do
        {address,
         [
           %{datetime: from, balance: balance_before},
           %{datetime: to, balance: balance_after}
         ]}
      end
    end)
    |> Enum.reject(&match?({:error, _}, &1))
  end

  @doc ~s"""
  Return a list of the `settings.metric` values for the necessary time range
  """
  def get_data(
        %__MODULE__{
          filtered_target: %{list: target_list, type: :slug},
          selector: selector
        } = settings
      ) do
    {from, to} = get_timeseries_params(settings)

    target_list
    |> Project.by_slug()
    |> Enum.map(fn %Project{} = project ->
      {:ok, eth_addresses} = Project.eth_addresses(project)

      eth_addresses = Enum.map(eth_addresses, &String.downcase/1)

      with {:ok, data} <- balance_change(selector, eth_addresses, from, to) do
        {balance_before, balance_after} =
          data
          |> Enum.reduce(
            {0, 0},
            fn {_, {balance_before, balance_after, _change}},
               {balance_before_acc, balance_after_acc} ->
              {balance_before + balance_before_acc, balance_after + balance_after_acc}
            end
          )

        data = [
          %{datetime: from, balance: balance_before},
          %{datetime: to, balance: balance_after}
        ]

        {project.slug, data}
      end
    end)
    |> Enum.reject(&match?({:error, _}, &1))
  end

  defp get_timeseries_params(%{time_window: time_window}) do
    to = Timex.now()
    from = Timex.shift(to, seconds: -str_to_sec(time_window))

    {from, to}
  end

  defp balance_change(selector, address, from, to) do
    cache_key =
      {:wallet_signal, selector, address, round_datetime(from, 300), round_datetime(to, 300)}
      |> Sanbase.Cache.hash()

    Sanbase.Signal.Evaluator.Cache.get_or_store(cache_key, fn ->
      case Sanbase.Clickhouse.HistoricalBalance.balance_change(
             selector,
             address,
             from,
             to
           ) do
        {:ok, result} ->
          {:ok, result}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defimpl Sanbase.Signal.Settings, for: WalletTriggerSettings do
    import Sanbase.Signal.Utils

    alias Sanbase.Signal.{OperationText, ResultBuilder}

    def triggered?(%WalletTriggerSettings{triggered?: triggered}), do: triggered

    def evaluate(%WalletTriggerSettings{} = settings, _trigger) do
      case WalletTriggerSettings.get_data(settings) do
        data when is_list(data) and data != [] ->
          build_result(data, settings)

        _ ->
          %WalletTriggerSettings{settings | triggered?: false}
      end
    end

    def build_result(data, %WalletTriggerSettings{} = settings) do
      ResultBuilder.build(data, settings, &template_kv/2, value_key: :balance)
    end

    def cache_key(%WalletTriggerSettings{} = settings) do
      construct_cache_key([
        settings.type,
        settings.target,
        settings.selector,
        settings.time_window,
        settings.operation
      ])
    end

    defp template_kv(values, %{filtered_target: %{type: :address}} = settings) do
      {operation_template, operation_kv} =
        OperationText.to_template_kv(values, settings.operation)

      {curr_value_template, curr_value_kv} =
        OperationText.current_value(values, settings.operation)

      asset_target_blockchain_kv = asset_target_blockchain_kv(settings.selector)

      kv =
        %{
          type: WalletTriggerSettings.type(),
          operation: settings.operation,
          address: settings.target.address
        }
        |> Map.merge(operation_kv)
        |> Map.merge(curr_value_kv)
        |> Map.merge(asset_target_blockchain_kv)

      template = """
      The address {{address}}'s {{asset}} balance on the {{target_blockchain}} blockchain has #{
        operation_template
      }.
      #{curr_value_template}
      """

      {template, kv}
    end

    defp template_kv(%{identifier: slug} = values, %{filtered_target: %{type: :slug}} = settings) do
      project = Project.by_slug(slug)

      {operation_template, operation_kv} =
        OperationText.to_template_kv(values, settings.operation)

      {curr_value_template, curr_value_kv} =
        OperationText.current_value(values, settings.operation)

      asset_target_blockchain_kv = asset_target_blockchain_kv(settings.selector)

      kv =
        %{
          type: WalletTriggerSettings.type(),
          project_name: project.name,
          project_ticker: project.ticker,
          project_slug: project.slug,
          operation: settings.operation
        }
        |> Map.merge(operation_kv)
        |> Map.merge(curr_value_kv)
        |> Map.merge(asset_target_blockchain_kv)

      template = """
      🔔 \#{{project_ticker}} | **{{project_name}}**'s {{asset}} balance on the {{target_blockchain}} blockchain has #{
        operation_template
      }.
      #{curr_value_template}
      """

      {template, kv}
    end

    defp asset_target_blockchain_kv(%{infrastructure: infrastructure} = selector) do
      case infrastructure do
        "ETH" -> %{asset: Map.get(selector, :slug, "ethereum"), target_blockchain: "Ethereum"}
        "BNB" -> %{asset: Map.get(selector, :slug, "binance-coin"), target_blockchain: "Binance"}
        "XRP" -> %{asset: Map.get(selector, :currency, "XRP"), target_blockchain: "Ripple"}
        "BTC" -> %{asset: "bitcoin", target_blockchain: "Bitcoin"}
        "BCH" -> %{asset: "bitcoin-cash", target_blockchain: "Bitcoin Cash"}
        "LTC" -> %{asset: "litecoin", target_blockchain: "Litecoin"}
      end
    end
  end
end
