defmodule Sanbase.Voting.PostTest do
  use Sanbase.DataCase, async: false

  alias Sanbase.Repo
  alias Sanbase.Auth.User
  alias Sanbase.Voting.{Poll, Post}

  test "create_changeset does not allow to approve the post" do
    poll =
      Poll.current_poll_changeset()
      |> Repo.insert!()

    user =
      %User{salt: User.generate_salt()}
      |> Repo.insert!()

    post =
      %Post{user_id: user.id, poll_id: poll.id}
      |> Post.create_changeset(%{
        link: "http://example.com",
        title: "Awesome article!",
        state: Post.approved_state()
      })
      |> Repo.insert!()

    assert post.state == nil
  end

  test "changeset allows to change the state of the post" do
    poll =
      Poll.current_poll_changeset()
      |> Repo.insert!()

    user =
      %User{salt: User.generate_salt()}
      |> Repo.insert!()

    post =
      %Post{user_id: user.id, poll_id: poll.id}
      |> Post.changeset(%{
        link: "http://example.com",
        title: "Awesome article!",
        state: Post.approved_state()
      })
      |> Repo.insert!()

    assert post.state == Post.approved_state()
  end
end
