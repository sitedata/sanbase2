defmodule SanbaseWeb.Graphql.ApiMetricAggregatedTimeseriesDataTest do
  use SanbaseWeb.ConnCase, async: false

  import Mock
  import Sanbase.Factory
  import SanbaseWeb.Graphql.TestHelpers
  import Sanbase.DateTimeUtils, only: [from_iso8601!: 1]

  alias Sanbase.Metric

  setup do
    %{user: user} = insert(:subscription_pro_sanbase, user: insert(:user))
    project = insert(:random_project)
    conn = setup_jwt_auth(build_conn(), user)

    [
      conn: conn,
      slug: project.slug,
      from: from_iso8601!("2019-01-01T00:00:00Z"),
      to: from_iso8601!("2019-01-02T00:00:00Z")
    ]
  end

  test "returns data for an available metric", context do
    %{conn: conn, slug: slug, from: from, to: to} = context
    aggregation = :avg
    [metric | _] = Metric.available_timeseries_metrics()

    with_mock Metric, [:passthrough],
      aggregated_timeseries_data: fn _, slug, _, _, _ ->
        {:ok, [%{slug: slug, value: 100}]}
      end do
      result =
        get_aggregated_timeseries_metric(conn, metric, slug, from, to, aggregation)
        |> extract_aggregated_timeseries_data()

      assert result == 100

      assert_called(
        Metric.aggregated_timeseries_data(metric, %{slug: slug}, from, to, aggregation)
      )
    end
  end

  test "returns data for all available metrics", context do
    %{conn: conn, slug: slug, from: from, to: to} = context
    aggregation = :avg
    metrics = Metric.available_timeseries_metrics()

    with_mock Metric, [:passthrough],
      aggregated_timeseries_data: fn _, slug_arg, _, _, _ ->
        {:ok, [%{slug: slug_arg, value: 100}]}
      end do
      for metric <- metrics do
        result =
          get_aggregated_timeseries_metric(conn, metric, slug, from, to, aggregation)
          |> extract_aggregated_timeseries_data()

        assert result == 100
      end
    end
  end

  test "returns data for all available aggregations", context do
    %{conn: conn, slug: slug, from: from, to: to} = context
    aggregations = Metric.available_aggregations()
    # nil means aggregation is not passed, we should not explicitly pass it
    aggregations = aggregations -- [nil]
    [metric | _] = Metric.available_timeseries_metrics()

    with_mock Metric, [:passthrough],
      aggregated_timeseries_data: fn _, slug, _, _, _ ->
        {:ok, [%{slug: slug, value: 100}]}
      end do
      for aggregation <- aggregations do
        result =
          get_aggregated_timeseries_metric(conn, metric, slug, from, to, aggregation)
          |> extract_aggregated_timeseries_data()

        assert result == 100
      end

      # Assert that all results are lists where we have a map with values
    end
  end

  test "returns error for unavailable aggregations", context do
    %{conn: conn, slug: slug, from: from, to: to} = context
    aggregations = Metric.available_aggregations()
    rand_aggregations = Enum.map(1..10, fn _ -> rand_str() |> String.to_atom() end)
    rand_aggregations = rand_aggregations -- aggregations
    [metric | _] = Metric.available_timeseries_metrics()

    # Do not mock the `get` function. It will reject the query if the execution
    # reaches it. Currently the execution is halted even earlier because the
    # aggregation is an enum with available values
    result =
      for aggregation <- rand_aggregations do
        get_aggregated_timeseries_metric(conn, metric, slug, from, to, aggregation)
      end

    # Assert that all results are lists where we have a map with values
    assert Enum.all?(result, &match?(%{"errors" => _}, &1))
  end

  test "returns error for unavailable metrics", context do
    %{conn: conn, slug: slug, from: from, to: to} = context
    aggregation = :avg
    rand_metrics = Enum.map(1..20, fn _ -> rand_str() end)
    rand_metrics = rand_metrics -- Metric.available_timeseries_metrics()

    # Do not mock the `timeseries_data` function because it's the one that rejects
    for metric <- rand_metrics do
      %{"errors" => [%{"message" => error_message}]} =
        get_aggregated_timeseries_metric(conn, metric, slug, from, to, aggregation)

      assert error_message == "The metric '#{metric}' is not supported or is mistyped."
    end
  end

  # Private functions

  defp get_aggregated_timeseries_metric(conn, metric, slug, from, to, aggregation) do
    query = get_aggregated_timeseries_query(metric, slug, from, to, aggregation)

    conn
    |> post("/graphql", query_skeleton(query, "getMetric"))
    |> json_response(200)
  end

  defp extract_aggregated_timeseries_data(result) do
    result
    |> get_in(["data", "getMetric", "aggregatedTimeseriesData"])
  end

  defp get_aggregated_timeseries_query(metric, slug, from, to, aggregation) do
    """
      {
        getMetric(metric: "#{metric}"){
          aggregatedTimeseriesData(
            slug: "#{slug}"
            from: "#{from}"
            to: "#{to}"
            aggregation: #{Atom.to_string(aggregation) |> String.upcase()})
        }
      }
    """
  end
end
