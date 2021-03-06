defmodule SanbaseWeb.Graphql.ChartConfigurationApiTest do
  use SanbaseWeb.ConnCase, async: false

  import SanbaseWeb.Graphql.TestHelpers
  import Sanbase.Factory

  setup do
    project = insert(:random_project)
    project2 = insert(:random_project)
    user = insert(:user)
    user2 = insert(:user)

    conn_no_user = build_conn()
    conn = setup_jwt_auth(build_conn(), user)
    conn2 = setup_jwt_auth(build_conn(), user2)

    post = insert(:post, user: user, title: "Title")

    settings = %{
      title: "My config",
      description: "some description",
      is_public: false,
      anomalies: ["daily_active_addesses_anomaly"],
      post_id: post.id,
      metrics: [
        "price_usd",
        "daily_active_addresses",
        "ethereum-CC-ETH-CC-daily_active_addresses"
      ],
      drawings: %{
        "lines" => [
          %{"x0" => 0, "y0" => 0, "x1" => 15, "y1" => 15},
          %{"x0" => 20, "y0" => 0, "x1" => 55, "y1" => 15}
        ]
      },
      options: %{
        "multi_chart" => true,
        "log_scale" => true
      },
      project_id: project.id
    }

    %{
      conn: conn,
      conn2: conn2,
      conn_no_user: conn_no_user,
      user: user,
      user2: user2,
      post: post,
      project: project,
      project2: project2,
      settings: settings
    }
  end

  describe "chart configuration mutations" do
    test "create", context do
      %{user: user, conn: conn, project: project, post: post, settings: settings} = context

      config =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration"])

      assert config["title"] == settings.title
      assert config["description"] == settings.description
      assert config["isPublic"] == settings.is_public
      assert config["anomalies"] == settings.anomalies
      assert config["metrics"] == settings.metrics
      assert config["drawings"] == settings.drawings
      assert config["options"] == settings.options
      assert config["project"]["id"] |> String.to_integer() == project.id
      assert config["project"]["slug"] == project.slug
      assert config["user"]["id"] |> String.to_integer() == user.id
      assert config["user"]["email"] == user.email
      assert config["post"]["id"] |> String.to_integer() == post.id
      assert config["post"]["title"] == post.title
    end

    test "update", context do
      %{conn: conn, settings: settings, user: user} = context

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      new_post = insert(:post, user: user, title: "New Title")

      new_settings = %{
        title: "New Title",
        description: "New description",
        is_public: true,
        metrics: ["getMetric|nvt"],
        anomalies: [],
        post_id: new_post.id,
        drawings: %{
          "circles" => [
            %{"cx" => 50, "cy" => 50, "r" => 20}
          ]
        },
        options: %{
          "multi_chart" => false,
          "log_scale" => true,
          "non_boolean_option" => 12
        }
      }

      config =
        update_chart_configuration(conn, config_id, new_settings)
        |> get_in(["data", "updateChartConfiguration"])

      assert config["title"] == new_settings.title
      assert config["description"] == new_settings.description
      assert config["isPublic"] == new_settings.is_public
      assert config["anomalies"] == new_settings.anomalies
      assert config["metrics"] == new_settings.metrics
      assert config["drawings"] == new_settings.drawings
      assert config["options"] == new_settings.options
      assert config["post"]["id"] |> String.to_integer() == new_settings.post_id
      assert config["post"]["title"] == new_post.title
    end

    test "cannot update other user's configuration", context do
      %{conn: conn, conn2: conn2, settings: settings} = context

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      error_msg =
        update_chart_configuration(conn2, config_id, %{title: "New Title"})
        |> get_in(["errors"])
        |> hd()
        |> Map.get("message")

      assert error_msg =~ "not owned by the user"
    end

    test "delete", context do
      %{conn: conn, settings: settings} = context

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      _ = delete_chart_configuration(conn, config_id)
      {:error, error_msg} = Sanbase.Chart.Configuration.by_id(config_id)
      assert error_msg =~ "does not exist"
    end
  end

  describe "chart configuration queries" do
    test "can query with anonymous user", context do
      %{conn: conn, conn_no_user: conn_no_user, settings: settings} = context

      # Create a public and private configuration

      config_id1 =
        create_chart_configuration(conn, %{settings | is_public: true})
        |> get_in(["data", "createChartConfiguration", "id"])

      config_id2 =
        create_chart_configuration(conn, %{settings | is_public: false})
        |> get_in(["data", "createChartConfiguration", "id"])

      # Test fetching configuratins with no logged in user

      config1 =
        get_chart_configuration(conn_no_user, config_id1)
        |> get_in(["data", "chartConfiguration"])

      assert config1["id"] == config_id1

      config2 =
        get_chart_configuration(conn_no_user, config_id2)
        |> get_in(["data", "chartConfiguration"])

      assert config2 == nil

      config_ids =
        get_chart_configurations(conn_no_user, nil, nil)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert config_ids == [config_id1]
    end

    test "can get all fields", context do
      %{user: user, conn: conn, project: project, post: post, settings: settings} = context

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      config =
        get_chart_configuration(conn, config_id)
        |> get_in(["data", "chartConfiguration"])

      assert config["title"] == settings.title
      assert config["description"] == settings.description
      assert config["isPublic"] == settings.is_public
      assert config["anomalies"] == settings.anomalies
      assert config["metrics"] == settings.metrics
      assert config["project"]["id"] |> String.to_integer() == project.id
      assert config["project"]["slug"] == project.slug
      assert config["user"]["id"] |> String.to_integer() == user.id
      assert config["user"]["email"] == user.email
      assert config["post"]["id"] |> String.to_integer() == post.id
      assert config["post"]["title"] == post.title
    end

    test "get own public configuration", context do
      %{conn: conn, settings: settings} = context
      settings = Map.put(settings, :is_public, true)

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      config =
        get_chart_configuration(conn, config_id)
        |> get_in(["data", "chartConfiguration"])

      assert config["id"] == config_id
    end

    test "get own private configuration", context do
      %{conn: conn, settings: settings} = context
      settings = Map.put(settings, :is_public, true)

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      config =
        get_chart_configuration(conn, config_id)
        |> get_in(["data", "chartConfiguration"])

      assert config["id"] == config_id
    end

    test "get other user's public configuration", context do
      %{conn: conn, conn2: conn2, settings: settings} = context
      settings = Map.put(settings, :is_public, true)

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      config =
        get_chart_configuration(conn2, config_id)
        |> get_in(["data", "chartConfiguration"])

      assert config["id"] == config_id
    end

    test "cannot get other user's private configuration", context do
      %{conn: conn, conn2: conn2, settings: settings} = context
      settings = Map.put(settings, :is_public, true)

      config_id =
        create_chart_configuration(conn, settings)
        |> get_in(["data", "createChartConfiguration", "id"])

      error_msg =
        update_chart_configuration(conn2, config_id, %{title: "New Title"})
        |> get_in(["errors"])
        |> hd()
        |> Map.get("message")

      assert error_msg =~ "not owned by the user"
    end

    test "get all chart configurations", context do
      %{conn: conn, conn2: conn2, settings: settings} = context
      settings = Map.put(settings, :is_public, true)

      [config_id1, config_id2, config_id3, config_id4] =
        [
          create_chart_configuration(conn, settings),
          create_chart_configuration(conn, settings),
          create_chart_configuration(conn2, settings),
          create_chart_configuration(conn2, settings |> Map.put(:is_public, false))
        ]
        |> Enum.map(&get_in(&1, ["data", "createChartConfiguration", "id"]))

      config_ids =
        get_chart_configurations(conn, nil, nil)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert config_id1 in config_ids
      assert config_id2 in config_ids
      assert config_id3 in config_ids
      refute config_id4 in config_ids
    end

    test "get all chart configurations of a user", context do
      %{conn: conn, conn2: conn2, user2: user2, settings: settings} = context
      settings = Map.put(settings, :is_public, true)

      [config_id1, config_id2, config_id3, config_id4] =
        [
          create_chart_configuration(conn, settings),
          create_chart_configuration(conn, settings),
          create_chart_configuration(conn2, settings),
          create_chart_configuration(conn2, %{settings | is_public: false})
        ]
        |> Enum.map(&get_in(&1, ["data", "createChartConfiguration", "id"]))

      # User gets their own public and private configurations
      config_ids =
        get_chart_configurations(conn2, user2.id, nil)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      refute config_id1 in config_ids
      refute config_id2 in config_ids
      assert config_id3 in config_ids
      assert config_id4 in config_ids

      # Get only public configurations of another user
      config_ids =
        get_chart_configurations(conn, user2.id, nil)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert length(config_ids) == 1
      assert config_id3 in config_ids
    end

    test "get all chart configurations for a project", context do
      %{conn: conn, conn2: conn2, project: project, project2: project2, settings: settings} =
        context

      settings = Map.put(settings, :is_public, true)

      [_, config_id2, config_id3, config_id4] =
        [
          create_chart_configuration(conn, %{settings | project_id: project.id}),
          create_chart_configuration(conn, %{settings | project_id: project2.id}),
          create_chart_configuration(conn2, %{settings | project_id: project2.id}),
          create_chart_configuration(conn2, %{
            settings
            | project_id: project2.id,
              is_public: false
          })
        ]
        |> Enum.map(&get_in(&1, ["data", "createChartConfiguration", "id"]))

      # Get all own and other users' public configurations for a project
      # Other users private configurations are hidden
      config_ids =
        get_chart_configurations(conn, nil, project2.id)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert length(config_ids) == 2
      assert config_id2 in config_ids
      assert config_id3 in config_ids

      # Get all own and other users' public configurations for a project
      # Own private configurations are accessible
      config_ids =
        get_chart_configurations(conn2, nil, project2.id)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert length(config_ids) == 3
      assert config_id2 in config_ids
      assert config_id3 in config_ids
      assert config_id4 in config_ids
    end

    test "get user's configurations for a given project", context do
      %{
        conn: conn,
        conn2: conn2,
        user: user,
        user2: user2,
        project: project,
        project2: project2,
        settings: settings
      } = context

      settings = Map.put(settings, :is_public, true)

      [_, _, config_id3, config_id4, _] =
        [
          create_chart_configuration(conn, %{settings | project_id: project.id}),
          create_chart_configuration(conn, %{settings | project_id: project.id}),
          create_chart_configuration(conn2, %{settings | project_id: project2.id}),
          create_chart_configuration(conn2, %{
            settings
            | project_id: project2.id,
              is_public: false
          }),
          create_chart_configuration(conn2, %{settings | project_id: project.id})
        ]
        |> Enum.map(&get_in(&1, ["data", "createChartConfiguration", "id"]))

      # No charts for a user and project
      config_ids =
        get_chart_configurations(conn, user.id, project2.id)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert config_ids == []

      # Get all public configurations of a user for a given project
      config_ids =
        get_chart_configurations(conn, user2.id, project2.id)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert length(config_ids) == 1
      assert config_id3 in config_ids

      # Get all own public and private configurations for a given project
      config_ids =
        get_chart_configurations(conn2, user2.id, project2.id)
        |> get_in(["data", "chartConfigurations"])
        |> Enum.map(& &1["id"])

      assert length(config_ids) == 2
      assert config_id3 in config_ids
      assert config_id4 in config_ids
    end
  end

  # Private functions

  defp create_chart_configuration(conn, settings) do
    query = """
    mutation {
      createChartConfiguration(settings: #{map_to_input_object_str(settings)}) {
        id
        title
        isPublic
        description
        user{ id email }
        project{ id slug }
        post{ id title }
        metrics
        anomalies
        drawings
        options
      }
    }
    """

    conn
    |> post("/graphql", mutation_skeleton(query))
    |> json_response(200)
  end

  defp update_chart_configuration(conn, config_id, settings) do
    query = """
    mutation {
      updateChartConfiguration(id: #{config_id}, settings: #{map_to_input_object_str(settings)}) {
        id
        title
        isPublic
        description
        user{ id email }
        project{ id slug }
        post{ id title }
        metrics
        anomalies
        drawings
        options
      }
    }
    """

    conn
    |> post("/graphql", mutation_skeleton(query))
    |> json_response(200)
  end

  defp delete_chart_configuration(conn, config_id) do
    query = """
    mutation {
      deleteChartConfiguration(id: #{config_id}) {
        id
        title
        isPublic
        description
        user{ id email }
        project{ id slug }
        post{ id title }
        metrics
        anomalies
        drawings
        options
      }
    }
    """

    conn
    |> post("/graphql", mutation_skeleton(query))
    |> json_response(200)
  end

  defp get_chart_configuration(conn, config_id) do
    query = """
    {
      chartConfiguration(id: #{config_id}) {
        id
        title
        isPublic
        description
        user{ id email }
        project{ id slug }
        post{ id title }
        metrics
        anomalies
        drawings
      }
    }
    """

    conn
    |> post("/graphql", query_skeleton(query))
    |> json_response(200)
  end

  defp get_chart_configurations(conn, nil, nil) do
    query = """
    {
      chartConfigurations {
        id
        title
        isPublic
        description
        user{ id email }
        project{ id slug }
        post{ id title }
        metrics
        anomalies
        drawings
      }
    }
    """

    conn
    |> post("/graphql", query_skeleton(query))
    |> json_response(200)
  end

  defp get_chart_configurations(conn, user_id, project_id) do
    query = """
    {
      chartConfigurations(
        #{if user_id, do: "user_id: #{user_id}"}
        #{if project_id, do: "project_id: #{project_id}"}
      ) {
        id
        title
        isPublic
        description
        user{ id email }
        project{ id slug }
        post{ id title }
        metrics
        anomalies
        drawings
      }
    }
    """

    conn
    |> post("/graphql", query_skeleton(query))
    |> json_response(200)
  end
end
