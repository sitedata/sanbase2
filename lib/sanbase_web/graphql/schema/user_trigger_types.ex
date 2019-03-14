defmodule SanbaseWeb.Graphql.UserTriggerTypes do
  use Absinthe.Schema.Notation

  object :user_trigger do
    field(:user_id, :integer)
    field(:trigger, :trigger)
  end

  object :trigger do
    field(:id, non_null(:integer))
    field(:title, non_null(:string))
    field(:description, :string)
    field(:icon_url, :string)
    field(:settings, non_null(:json))
    field(:is_public, :boolean)
    field(:cooldown, :string)
    field(:tags, list_of(:tag))
    field(:active, non_null(:boolean))
    field(:repeating, non_null(:boolean))
  end
end
