defmodule Sanbase.Model.Whitepaper do
  use Ecto.Schema
  import Ecto.Changeset
  alias Sanbase.Model.Whitepaper
  alias Sanbase.Model.Project


  schema "whitepapers" do
    field :authors, :integer
    field :citations, :integer
    field :link, :string
    field :pages, :integer
    belongs_to :project, Project
  end

  @doc false
  def changeset(%Whitepaper{} = whitepaper, attrs \\ %{}) do
    whitepaper
    |> cast(attrs, [:link, :authors, :pages, :citations, :project_id])
    |> validate_required([:project_id])
    |> unique_constraint(:project_id)
  end
end
