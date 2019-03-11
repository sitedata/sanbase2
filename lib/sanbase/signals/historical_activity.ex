defmodule Sanbase.Signals.HistoricalActivity do
  @moduledoc ~s"""
  Table that persists triggered signals and their payload.
  """
  @derive [Jason.Encoder]

  use Ecto.Schema
  import Ecto.Query

  import Ecto.Changeset
  alias Sanbase.Signals.UserTrigger
  alias Sanbase.Auth.User
  alias Sanbase.Repo

  alias __MODULE__

  schema "signals_historical_activity" do
    belongs_to(:user, User)
    belongs_to(:user_trigger, UserTrigger)
    field(:payload, :map)
    field(:triggered_at, :naive_datetime)
  end

  def changeset(%HistoricalActivity{} = user_signal, attrs \\ %{}) do
    user_signal
    |> cast(attrs, [:user_id, :user_trigger_id, :payload, :triggered_at])
    |> validate_required([:user_id, :user_trigger_id, :payload, :triggered_at])
  end

  @doc """
  Fetch signal historical activity for user with before and after cursors ordered by triggered_at descending
  * `before` cursor is pointed at the last record of the return list. 
    It is used for fetching messages `before` certain datetime
  * `after` cursor is pointed at latest message. It is used for fetching the latest signal activity.
  """

  def fetch_historical_activity_for(
        %User{id: user_id},
        %{limit: limit, cursor: %{type: cursor_type, datetime: cursor_datetime}}
      ) do
    HistoricalActivity
    |> user_historical_activity(user_id, limit)
    |> by_cursor(cursor_type, cursor_datetime)
    |> Repo.all()
    |> activity_with_cursors()
  end

  def fetch_historical_activity_for(%User{id: user_id}, %{limit: limit}) do
    HistoricalActivity
    |> user_historical_activity(user_id, limit)
    |> Repo.all()
    |> activity_with_cursors()
  end

  def fetch_historical_activity_for(_, _), do: {:error, "Bad arguments"}

  # private functions

  defp user_historical_activity(query, user_id, limit) do
    from(
      ha in query,
      where: ha.user_id == ^user_id,
      order_by: [desc: ha.triggered_at],
      limit: ^limit,
      preload: :user_trigger
    )
  end

  defp by_cursor(query, :before, datetime) do
    from(
      ha in query,
      where: ha.triggered_at < ^datetime
    )
  end

  defp by_cursor(query, :after, datetime) do
    from(
      ha in query,
      where: ha.triggered_at > ^datetime
    )
  end

  defp activity_with_cursors([]), do: {:ok, %{activity: [], cursor: %{}}}

  defp activity_with_cursors(activity) do
    before_datetime = activity |> List.last() |> Map.get(:triggered_at)
    after_datetime = activity |> List.first() |> Map.get(:triggered_at)

    {:ok,
     %{
       activity: activity,
       cursor: %{before: before_datetime, after: after_datetime}
     }}
  end
end
