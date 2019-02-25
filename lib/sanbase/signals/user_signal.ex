defmodule Sanbase.Signals.UserSignal do
  @moduledoc ~s"""
  Table that persists triggered signals and their payload.
  """
  @derive [Jason.Encoder]

  use Ecto.Schema

  import Ecto.Changeset
  alias Sanbase.Signals.UserTrigger
  alias Sanbase.Auth.User

  alias __MODULE__

  schema "user_signals" do
    belongs_to(:user, User)
    belongs_to(:user_trigger, UserTrigger)
    field(:payload, :map)

    timestamps()
  end

  def changeset(%UserSignal{} = user_signal, attrs \\ %{}) do
    user_signal
    |> cast(attrs, [:user_id, :user_trigger_id, :payload])
    |> validate_required([:user_id, :user_trigger_id, :payload])
  end
end
