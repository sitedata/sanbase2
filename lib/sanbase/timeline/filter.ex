defmodule Sanbase.Timeline.Filter do
  import Ecto.Query

  alias Sanbase.Timeline.Query

  alias Sanbase.UserList
  alias Sanbase.Signal.UserTrigger
  alias Sanbase.Insight.Post
  alias Sanbase.Repo

  def filter_by_query(query, filter_by, user_id) do
    query
    |> filter_by_author_query(filter_by, user_id)
    |> filter_by_watchlists_query(filter_by)
    |> filter_by_assets_query(filter_by, user_id)
  end

  defp filter_by_author_query(query, %{author: :all}, user_id) do
    Query.events_by_sanfamily_or_followed_users_or_own_query(query, user_id)
  end

  defp filter_by_author_query(query, %{author: :sanfam}, _) do
    Query.events_by_sanfamily_query(query)
  end

  defp filter_by_author_query(query, %{author: :followed}, user_id) do
    Query.events_by_followed_users_query(query, user_id)
  end

  defp filter_by_author_query(query, %{author: :own}, user_id) do
    Query.events_by_current_user_query(query, user_id)
  end

  defp filter_by_author_query(query, _, user_id) do
    Query.events_by_sanfamily_or_followed_users_or_own_query(query, user_id)
  end

  defp filter_by_watchlists_query(query, %{watchlists: watchlists})
       when is_list(watchlists) and length(watchlists) > 0 do
    from(event in query, where: event.user_list_id in ^watchlists)
  end

  defp filter_by_watchlists_query(query, _), do: query

  defp filter_by_assets_query(query, %{assets: assets} = filter_by, user_id)
       when is_list(assets) and length(assets) > 0 do
    {slugs, tickers} = get_slugs_and_tickers_by_asset_list(assets)
    watchlist_ids = get_watchlist_ids_by_asset_list(assets, filter_by, user_id)
    insight_ids = get_insight_ids_by_asset_list({slugs, tickers}, filter_by, user_id)
    trigger_ids = get_trigger_ids_by_asset_list({slugs, tickers}, filter_by, user_id)

    from(event in query,
      where:
        event.user_list_id in ^watchlist_ids or
          event.post_id in ^insight_ids or
          event.user_trigger_id in ^trigger_ids
    )
  end

  defp filter_by_assets_query(query, _, _), do: query

  defp get_watchlist_ids_by_asset_list(assets, filter_by, user_id) do
    from(
      entity in UserList,
      join: li in assoc(entity, :list_items),
      where: li.project_id in ^assets,
      select: entity.id
    )
    |> filter_by_author_query(filter_by, user_id)
    |> Repo.all()
  end

  defp get_slugs_and_tickers_by_asset_list(assets) do
    project_slugs_and_tickers =
      from(p in Sanbase.Model.Project, where: p.id in ^assets, select: [p.slug, p.ticker])
      |> Repo.all()

    slugs = project_slugs_and_tickers |> Enum.map(fn [slug, _] -> slug end)
    tickers = project_slugs_and_tickers |> Enum.map(fn [_, ticker] -> ticker end)

    {slugs, tickers}
  end

  defp get_insight_ids_by_asset_list({slugs, tickers}, filter_by, user_id) do
    from(
      entity in Post,
      join: t in assoc(entity, :tags),
      where: t.name in ^slugs or t.name in ^tickers,
      select: entity.id
    )
    |> filter_by_author_query(filter_by, user_id)
    |> Repo.all()
  end

  defp get_trigger_ids_by_asset_list({slugs, tickers}, filter_by, user_id) do
    triggers =
      from(ut in UserTrigger, select: [ut.id, fragment("trigger->'settings'->'target'")])
      |> filter_by_author_query(filter_by, user_id)
      |> Repo.all()

    triggers
    |> Enum.filter(fn [_id, target] -> filter_by_trigger_target(target, {slugs, tickers}) end)
    |> Enum.map(fn [id, _] -> id end)
  end

  defp filter_by_trigger_target(%{"slug" => slug}, {slugs, _tickers}) when is_binary(slug),
    do: slug in slugs

  defp filter_by_trigger_target(%{"slug" => target_slugs}, {slugs, _tickers})
       when is_binary(target_slugs) do
    has_intersection?(target_slugs, slugs)
  end

  defp filter_by_trigger_target(%{"word" => word}, {slugs, tickers}) when is_binary(word) do
    word in slugs or String.upcase(word) in tickers
  end

  defp filter_by_trigger_target(%{"word" => words}, {slugs, tickers}) when is_list(words) do
    words_upcase = words |> Enum.map(&String.upcase/1)

    has_intersection?(words, slugs) or has_intersection?(words_upcase, tickers)
  end

  defp has_intersection?(list1, list2) do
    MapSet.intersection(MapSet.new(list1), MapSet.new(list2)) |> MapSet.size() > 0
  end
end