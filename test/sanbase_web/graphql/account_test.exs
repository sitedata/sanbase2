defmodule SanbaseWeb.Graphql.AccountTest do
  use SanbaseWeb.ConnCase
  use Phoenix.ConnTest

  import Plug.Conn

  alias Sanbase.Model.Project
  alias Sanbase.Auth.User
  alias Sanbase.Repo
  alias SanbaseWeb.Graphql.ContextPlug

  defp mutation_skeleton(query) do
    %{
      "operationName" => "",
      "query" => "#{query}",
      "variables" => ""
    }
  end

  setup do
    user =
      %User{salt: User.generate_salt()}
      |> Repo.insert!()

    {:ok, token, _claims} = SanbaseWeb.Guardian.encode_and_sign(user, %{salt: user.salt})

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token)

    conn = ContextPlug.call(conn, %{})

    assert conn.private[:absinthe] == %{
             context: %{auth: %{auth_method: :user_token, current_user: user}}
           }

    {:ok, conn: conn}
  end

  test "change email of current user", context do
    new_email = "new_test_email@santiment.net"

    query = """
    mutation {
      changeEmail(email: "#{new_email}") {
        email
      }
    }
    """

    result =
      context.conn
      |> post("/graphql", mutation_skeleton(query))

    assert json_response(result, 200)["data"]["changeEmail"]["email"] == new_email
  end

  test "follow and unfollow a project", context do
    project =
      %Project{name: "TestProjectName"}
      |> Repo.insert!()

    follow_mutation = """
    mutation {
      followProject(projectId: #{project.id}){
        followedProjects {
          id
        }
      }
    }
    """

    follow_result =
      context.conn
      |> post("/graphql", mutation_skeleton(follow_mutation))

    assert [%{"id" => "#{project.id}"}] ==
             json_response(follow_result, 200)["data"]["followProject"]["followedProjects"]

    unfollow_mutation = """
    mutation {
      unfollowProject(projectId: #{project.id}){
        followedProjects {
          id
        }
      }
    }
    """

    unfollow_result =
      context.conn
      |> post("/graphql", mutation_skeleton(unfollow_mutation))

    followed_projects =
      json_response(unfollow_result, 200)["data"]["followProject"]["followedProjects"]

    assert followed_projects == nil || [%{"ticker" => "#{project.id}"}] not in followed_projects
  end
end