defmodule SanbaseWeb.Graphql.MetricTypes do
  use Absinthe.Schema.Notation

  import SanbaseWeb.Graphql.Cache, only: [cache_resolve: 1, cache_resolve: 2]

  alias Sanbase.Metric

  alias SanbaseWeb.Graphql.Complexity
  alias SanbaseWeb.Graphql.Middlewares.AccessControl
  alias SanbaseWeb.Graphql.Resolvers.MetricResolver

  object :metric_data do
    field(:datetime, non_null(:datetime))
    field(:value, :float)
  end

  object :string_list do
    field(:data, list_of(:string))
  end

  object :float_list do
    field(:data, list_of(:float))
  end

  union :value_list do
    description("Type Parameterized Array")

    types([:string_list, :float_list])

    resolve_type(fn
      %{data: [value | _]}, _ when is_number(value) -> :float_list
      %{data: [value | _]}, _ when is_binary(value) -> :string_list
      %{data: []}, _ -> :float_list
    end)
  end

  object :histogram_data do
    field(:labels, non_null(list_of(:string)))
    field(:values, :value_list)
  end

  object :metric_metadata do
    @desc ~s"""
    The name of the metric the metadata is about
    """
    field(:metric, non_null(:string))

    @desc ~s"""
    List of slugs which can be provided to the `timeseriesData` field to fetch
    the metric.
    """
    field :available_slugs, list_of(:string) do
      cache_resolve(&MetricResolver.get_available_slugs/3, ttl: 600)
    end

    @desc ~s"""
    The minimal granularity for which the data is available.
    """
    field(:min_interval, :string)

    @desc ~s"""
    When the interval provided in the query is bigger than `min_interval` and
    contains two or more data points, the data must be aggregated into a single
    data point. The default aggregation that is applied is this `default_aggregation`.
    The default aggregation can be changed by the `aggregation` parameter of
    the `timeseriesData` field. Available aggregations are:
    [
    #{
      (Metric.available_aggregations() -- [nil])
      |> Enum.map(&Atom.to_string/1)
      |> Enum.map(&String.upcase/1)
      |> Enum.join(",")
    }
    ]
    """
    field(:default_aggregation, :aggregation)

    @desc ~s"""
    The supported aggregations for this metric. For more information about
    aggregations see the documentation for `defaultAggregation`
    """
    field(:available_aggregations, list_of(:aggregation))

    field(:data_type, :metric_data_type)
  end

  object :metric do
    @desc ~s"""
    Return a list of 'datetime' and 'value' for a given metric, slug
    and time period.

    The 'includeIncompleteData' flag has a default value 'false'.

    Some metrics may have incomplete data for the last data point (usually today)
    as they are computed since the beginning of the day. An example is daily
    active addresses for today - at 12:00pm it will contain the data only
    for the last 12 hours, not for a whole day. This incomplete data can be
    confusing so it is excluded by default. If this incomplete data is needed,
    the flag includeIncompleteData should be set to 'true'.

    Incomplete data can still be useful. Here are two examples:
    Daily Active Addresses: The number is only going to increase during the day,
    so if the intention is to see when they reach over a threhsold the incomplete
    data gives more timely signal.

    NVT: Due to the way it is computed, the value is only going to decrease
    during the day, so if the intention is to see when it falls below a threhsold,
    the incomplete gives more timely signal.
    """
    field :timeseries_data, list_of(:metric_data) do
      arg(:slug, non_null(:string))
      arg(:from, non_null(:datetime))
      arg(:to, non_null(:datetime))
      arg(:interval, :interval, default_value: "1d")
      arg(:aggregation, :aggregation, default_value: nil)
      arg(:include_incomplete_data, :boolean, default_value: false)

      complexity(&Complexity.from_to_interval/3)
      middleware(AccessControl)

      cache_resolve(&MetricResolver.timeseries_data/3)
    end

    field :histogram_data, :histogram_data do
      arg(:slug, non_null(:string))
      arg(:from, non_null(:datetime))
      arg(:to, non_null(:datetime))
      arg(:interval, :interval, default_value: "1d")
      arg(:limit, :integer, default_value: 100)

      complexity(&Complexity.from_to_interval/3)
      middleware(AccessControl)

      resolve(&MetricResolver.histogram_data/3)
    end

    field :available_since, :datetime do
      arg(:slug, non_null(:string))
      cache_resolve(&MetricResolver.available_since/3)
    end

    field :last_datetime_computed_at, :datetime do
      arg(:slug, non_null(:string))
      cache_resolve(&MetricResolver.last_datetime_computed_at/3)
    end

    field :metadata, :metric_metadata do
      cache_resolve(&MetricResolver.get_metadata/3)
    end
  end

  enum :metric_data_type do
    value(:timeseries)
    value(:histogram)
  end
end
