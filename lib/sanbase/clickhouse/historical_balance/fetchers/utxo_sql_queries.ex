defmodule Sanbase.Clickhouse.HistoricalBalance.UtxoSqlQueries do
  @moduledoc ~s"""
  Common SQL queries for fetching historical balances and balance changes for
  UTXO blockhains like Bitcoin, Litecoin, Bitcoin Cash, etc.
  """
  def last_balance_before_query(table, address, datetime) do
    query = """
    SELECT balance
    FROM #{table}
    PREWHERE
      address = ?1 AND
      dt <=toDateTime(?2)
    ORDER BY dt DESC
    LIMIT 1
    """

    args = [address, DateTime.to_unix(datetime)]

    {query, args}
  end

  def current_balance_query(table, address) do
    query = """
    SELECT balance
    FROM #{table}
    PREWHERE
      address = ?1
    ORDER BY dt DESC
    LIMIT 1
    """

    args = [address]
    {query, args}
  end

  def historical_balance_query(table, address, from, to, interval) when is_binary(address) do
    interval = Sanbase.DateTimeUtils.str_to_sec(interval)
    from_unix = DateTime.to_unix(from)
    to_unix = DateTime.to_unix(to)
    span = div(to_unix - from_unix, interval) |> max(1)

    query = """
    SELECT time, SUM(balance), toUInt8(SUM(has_changed))
      FROM (
        SELECT
          toUnixTimestamp(intDiv(toUInt32(?4 + number * ?1), ?1) * ?1) AS time,
          toFloat64(0) AS balance,
          toInt8(0) AS has_changed
        FROM numbers(?2)

      UNION ALL

      SELECT
        toUnixTimestamp(intDiv(toUInt32(dt), ?1) * ?1) AS time,
        argMax(balance, dt) AS balance,
        toUInt8(1) AS has_changed
      FROM #{table}
      PREWHERE
        address = ?3 AND
        dt >= toDateTime(?4) AND
        dt <= toDateTime(?5)
      GROUP BY time
    )
    GROUP BY time
    ORDER BY time
    """

    args = [interval, span, address, from_unix, to_unix]
    {query, args}
  end

  def balance_change_query(table, address_or_addresses, from, to) do
    addresses = address_or_addresses |> List.wrap() |> List.flatten()

    query = """
    SELECT
      address,
      argMaxIf(balance, dt, dt <= ?3) AS start_balance,
      argMaxIf(balance, dt, dt <= ?4) AS end_balance,
      end_balance - start_balance AS diff
    FROM #{table} FINAL
    PREWHERE
      address IN (?1)
    GROUP BY address
    """

    args = [addresses, from, to]

    {query, args}
  end

  def historical_balance_change_query(table, address_or_addresses, from, to, interval) do
    addresses = address_or_addresses |> List.wrap() |> List.flatten()

    interval = Sanbase.DateTimeUtils.str_to_sec(interval)
    to_unix = DateTime.to_unix(to)
    from_unix = DateTime.to_unix(from)
    span = div(to_unix - from_unix, interval) |> max(1)

    # The balances table is like a stack. For each balance change there is a record
    # with sign = -1 that is the old balance and with sign = 1 which is the new balance
    query = """
    SELECT time, SUM(change)
      FROM (
        SELECT
          toUnixTimestamp(intDiv(toUInt32(?4 + number * ?1), ?1) * ?1) AS time,
          toFloat64(0) AS change
        FROM numbers(?2)

      UNION ALL

      SELECT
        toUnixTimestamp(intDiv(toUInt32(dt), ?1) * ?1) AS time,
        balance - oldBalance AS change
      FROM #{table} FINAL
      PREWHERE
        address in (?3) AND
        dt >= toDateTime(?4) AND
        dt < toDateTime(?5)
      GROUP BY address
    )
    GROUP BY time
    ORDER BY time
    """

    args = [interval, span, addresses, from_unix, to_unix]
    {query, args}
  end
end
