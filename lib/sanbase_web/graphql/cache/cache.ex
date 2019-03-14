defmodule SanbaseWeb.Graphql.Cache do
  @moduledoc ~s"""
  Provides the macro `cache_resolve` that replaces the Absinthe's `resolve` and
  caches the result of the resolver for a some time instead of precalculating itt
  each time.
  """
  require Logger

  @ttl :timer.minutes(5)
  @cache_name :graphql_cache

  alias __MODULE__, as: CacheMod
  alias SanbaseWeb.Graphql.ConCacheProvider, as: CacheProvider

  @doc ~s"""
  Macro that's used instead of Absinthe's `resolve`. This resolver can perform
  the following operations:
  1. Get the value from a cache if it is persisted. The resolver function is not
  2. Calculate and store the value in the cache if it is not present in the cache
  3. Handle middleware results

  There are 2 options for the passed function.
  1. It can be a captured named function because its name is extracted
  and used in the cache key.
  2. If the function is anonymous or a different name should be used, a second
  parameter with that name must be passed.

  Just like `resolve` comming from Absinthe, `cache_resolve` supports the `{:ok, value}`
  and `{:error, reason}` result tuples. The `:ok` tuples are cached while the `:error`
  tuples are not.

  But `cache_resolve` knows how to handle a third type of response format. When
  `{:nocache, {:ok, value}}` is returned as the result the cache does **not** cache
  the value and just returns `{:ok, value}`. This is particulary useful when
  the result can't be constructed but returning an error will crash the whole query.
  In such cases a default/filling value can be passed (0, nil, "No data", etc.)
  and the next query will try to resolve it again
  """
  defmacro cache_resolve(captured_mfa_ast, fun_name \\ nil) do
    quote do
      middleware(
        Absinthe.Resolution,
        CacheMod.from(unquote(captured_mfa_ast), unquote(fun_name))
      )
    end
  end

  @doc ~s"""
  Exposed as sometimes it can be useful to use it outside the macros.

  Gets a function, name and arguments and returns a new function that:
  1. On execution checks if the value is present in the cache and returns it
  2. If it's not in the cache it gets executed and the value is stored in the cache.

  NOTE: `cached_func` is a function with arity 0. That means if you want to use it
  in your code and you want some arguments you should use it like this:
    > Cache.func(
    >   fn ->
    >     fetch_last_price_record(pair)
    >   end,
    >   :fetch_price_last_record, %{pair: pair}
    > ).()
  """
  def func(cached_func, name, args \\ %{}) do
    fn ->
      CacheProvider.get_or_store(
        @cache_name,
        cache_key(name, args),
        cached_func,
        &cache_modify_middleware/3
      )
    end
  end

  @doc ~s"""
  Clears the whole cache. Slow.
  """
  def clear_all() do
    CacheProvider.clear_all(@cache_name)
  end

  @doc ~s"""
  The size of the cache in megabytes
  """
  def size() do
    CacheProvider.size(@cache_name, :megabytes)
  end

  @doc false
  def from(captured_mfa, nil) when is_function(captured_mfa) do
    # Public so it can be used by the resolve macros. You should not use it.
    fun_name = captured_mfa |> captured_mfa_name()

    resolver(captured_mfa, fun_name)
  end

  @doc false
  def from(fun, fun_name) when is_function(fun) do
    # Public so it can be used by the resolve macros. You should not use it.
    resolver(fun, fun_name)
  end

  # Private functions

  defp resolver(resolver_fn, name) do
    # Works only for top-level resolvers and fields with root object that has `id` field
    fn
      %{id: id} = root, args, resolution ->
        fun = fn -> resolver_fn.(root, args, resolution) end

        cache_key({name, id}, args)
        |> get_or_store(fun)

      %{word: word} = root, args, resolution ->
        fun = fn -> resolver_fn.(root, args, resolution) end

        cache_key({name, word}, args)
        |> get_or_store(fun)

      %{}, args, resolution ->
        fun = fn -> resolver_fn.(%{}, args, resolution) end

        cache_key(name, args)
        |> get_or_store(fun)
    end
  end

  defp get_or_store(cache_name \\ @cache_name, cache_key, resolver_fn) do
    CacheProvider.get_or_store(
      cache_name,
      cache_key,
      resolver_fn,
      &cache_modify_middleware/3
    )
  end

  # `cache_modify_middleware` is called only from withing `get_or_store` that
  # guarantees that it will be executed only once if it is accessed concurently.
  # This is way it is safe to use `store` explicitly without worrying about race
  # conditions
  defp cache_modify_middleware(cache_name, cache_key, {:ok, value} = result) do
    CacheProvider.store(cache_name, cache_key, result)

    {:ok, value}
  end

  defp cache_modify_middleware(
         cache_name,
         cache_key,
         {:middleware, Absinthe.Middleware.Async = midl, {fun, opts}}
       ) do
    caching_fun = fn ->
      CacheProvider.get_or_store(cache_name, cache_key, fun, &cache_modify_middleware/3)
    end

    {:middleware, midl, {caching_fun, opts}}
  end

  defp cache_modify_middleware(
         cache_name,
         cache_key,
         {:middleware, Absinthe.Middleware.Dataloader = midl, {loader, callback}}
       ) do
    caching_callback = fn loader_arg ->
      CacheProvider.get_or_store(
        cache_name,
        cache_key,
        fn -> callback.(loader_arg) end,
        &cache_modify_middleware/3
      )
    end

    {:middleware, midl, {loader, caching_callback}}
  end

  # Helper functions

  defp cache_key(name, args) do
    args_hash =
      args
      |> convert_values()
      |> Jason.encode!()
      |> sha256()

    {name, args_hash}
  end

  # Convert the values for using in the cache. A special treatement is done for
  # `%DateTime{}` so all datetimes in a @ttl sized window are treated the same
  defp convert_values(args) do
    args
    |> Enum.map(fn
      {k, %DateTime{} = v} ->
        {k, div(DateTime.to_unix(v, :millisecond), @ttl)}

      pair ->
        pair
    end)
    |> Map.new()
  end

  defp sha256(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16()
  end

  defp captured_mfa_name(captured_mfa) do
    captured_mfa
    |> :erlang.fun_info()
    |> Keyword.get(:name)
  end
end
