defmodule Sanbase.Signal.WalletTriggerTest do
  use Sanbase.DataCase, async: false

  import Mock
  import Sanbase.Factory

  alias Sanbase.Model.Project

  alias Sanbase.Signal.{
    UserTrigger,
    Trigger.WalletTriggerSettings,
    Scheduler
  }

  alias Sanbase.Clickhouse.HistoricalBalance

  setup_with_mocks([
    {Sanbase.GoogleChart, [],
     [
       build_embedded_chart: fn _, _, _, _ -> [%{image: %{url: "somelink"}}] end,
       build_embedded_chart: fn _, _, _ -> [%{image: %{url: "somelink"}}] end
     ]}
  ]) do
    Sanbase.Signal.Evaluator.Cache.clear()

    user = insert(:user)
    Sanbase.Auth.UserSettings.set_telegram_chat_id(user.id, 123_123_123_123)

    project = Sanbase.Factory.insert(:random_erc20_project)

    {:ok, [address]} = Project.eth_addresses(project)

    trigger_settings1 = %{
      type: "wallet_movement",
      selector: %{infrastructure: "ETH", slug: "ethereum"},
      target: %{slug: project.slug},
      channel: "telegram",
      time_window: "1d",
      operation: %{amount_up: 25.0}
    }

    trigger_settings2 = %{
      type: "wallet_movement",
      selector: %{infrastructure: "EOS", slug: "some-weird-token"},
      target: %{address: address},
      channel: "telegram",
      time_window: "1d",
      operation: %{amount_up: 200.0}
    }

    trigger_settings3 = %{
      type: "wallet_movement",
      selector: %{infrastructure: "XRP", currency: "BTC"},
      target: %{address: address},
      channel: "telegram",
      time_window: "1d",
      operation: %{amount_down: 50.0}
    }

    {:ok, _} =
      UserTrigger.create_user_trigger(user, %{
        title: "Generic title",
        is_public: true,
        cooldown: "12h",
        settings: trigger_settings1
      })

    {:ok, _} =
      UserTrigger.create_user_trigger(user, %{
        title: "Generic title",
        is_public: true,
        cooldown: "1d",
        settings: trigger_settings2
      })

    {:ok, _} =
      UserTrigger.create_user_trigger(user, %{
        title: "Generic title",
        is_public: true,
        cooldown: "1d",
        settings: trigger_settings3
      })

    [
      project: project,
      address: address
    ]
  end

  test "triggers eth wallet signal when balance increases", context do
    test_pid = self()

    with_mocks [
      {Sanbase.Telegram, [:passthrough],
       send_message: fn _user, text ->
         send(test_pid, {:telegram_to_self, text})
         :ok
       end},
      {HistoricalBalance, [:passthrough],
       balance_change: fn _, _, _, _ ->
         {:ok, [{context.address, {20, 70, 50}}]}
       end}
    ] do
      Scheduler.run_signal(WalletTriggerSettings)

      assert_receive({:telegram_to_self, message})

      assert message =~
               "The ethereum balance on the Ethereum blockchain of the project **#{
                 context.project.name
               }** has increased by 50"
    end
  end

  test "triggers eth wallet and address signals when balance increases", context do
    test_pid = self()

    with_mocks [
      {Sanbase.Telegram, [:passthrough],
       send_message: fn _user, text ->
         send(test_pid, {:telegram_to_self, text})
         :ok
       end},
      {HistoricalBalance, [:passthrough],
       balance_change: fn _, _, _, _ ->
         {:ok, [{context.address, {20, 300, 280}}]}
       end}
    ] do
      Scheduler.run_signal(WalletTriggerSettings)

      assert_receive({:telegram_to_self, message1})
      assert_receive({:telegram_to_self, message2})

      # Plain sort won't work as depends on the randomly generated project name
      # Sorting on wheter there is `address` substring is deterministic
      sorted_messages = Enum.sort_by([message1, message2], &String.contains?(&1, "address"))

      assert Enum.at(sorted_messages, 0) =~
               "The ethereum balance on the Ethereum blockchain of the project **#{
                 context.project.name
               }** has increased by 280"

      assert Enum.at(sorted_messages, 1) =~
               "The some-weird-token balance on the EOS blockchain of the address #{
                 context.address
               } has increased by 280"
    end
  end

  test "triggers address signal when balance decreases", context do
    test_pid = self()

    with_mocks [
      {Sanbase.Telegram, [:passthrough],
       send_message: fn _user, text ->
         send(test_pid, {:telegram_to_self, text})
         :ok
       end},
      {HistoricalBalance, [:passthrough],
       balance_change: fn _, _, _, _ ->
         {:ok, [{context.address, {100, 0, -100}}]}
       end}
    ] do
      Scheduler.run_signal(WalletTriggerSettings)

      assert_receive({:telegram_to_self, message})

      assert message =~
               "The BTC balance on the Ripple blockchain of the address #{context.address} has decreased by 100"
    end
  end

  test "behavior is correct in case of database error" do
    test_pid = self()

    with_mocks [
      {Sanbase.Telegram, [:passthrough],
       send_message: fn _user, text ->
         send(test_pid, {:telegram_to_self, text})
         :ok
       end},
      {HistoricalBalance, [:passthrough],
       balance_change: fn _, _, _, _ ->
         {:error, "Something bad happened"}
       end}
    ] do
      Scheduler.run_signal(WalletTriggerSettings)

      refute_receive({:telegram_to_self, _})
    end
  end
end
