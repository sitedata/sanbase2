defmodule Sanbase.DateTimeUtils do
  def seconds_after(seconds, datetime \\ DateTime.utc_now()) do
    datetime
    |> Timex.shift(seconds: seconds)
  end

  def days_after(days, datetime \\ DateTime.utc_now()) do
    seconds_after(days * 60 * 60 * 24, datetime)
  end

  def seconds_ago(seconds, datetime \\ DateTime.utc_now()) do
    datetime
    |> Timex.shift(seconds: -seconds)
  end

  def minutes_ago(minutes) do
    seconds_ago(minutes * 60)
  end

  def hours_ago(hours) do
    seconds_ago(hours * 60 * 60)
  end

  def days_ago(days) do
    seconds_ago(days * 60 * 60 * 24)
  end

  def start_of_day(datetime \\ DateTime.utc_now()) do
    %DateTime{datetime | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  # Interval should be an integer followed by one of: s, m, h, d or w
  def str_to_sec(interval) do
    interval_type = String.last(interval)

    String.slice(interval, 0..-2)
    |> String.to_integer()
    |> str_to_sec(interval_type)
  end

  def str_to_hours(interval) do
    str_to_sec(interval) |> Integer.floor_div(3600)
  end

  defp str_to_sec(seconds, "s"), do: seconds
  defp str_to_sec(minutes, "m"), do: minutes * 60
  defp str_to_sec(hours, "h"), do: hours * 60 * 60
  defp str_to_sec(days, "d"), do: days * 60 * 60 * 24
  defp str_to_sec(weeks, "w"), do: weeks * 60 * 60 * 24 * 7

  def ecto_date_to_datetime(ecto_date) do
    {:ok, datetime, _} =
      (Ecto.Date.to_iso8601(ecto_date) <> "T00:00:00Z") |> DateTime.from_iso8601()

    datetime
  end

  def compound_duration_to_seconds(interval) do
    {int_interval, duration_index} = Integer.parse(interval)

    case duration_index do
      "ns" -> div(int_interval, 1_000_000_000)
      "s" -> int_interval
      "m" -> int_interval * 60
      "h" -> int_interval * 60 * 60
      "d" -> int_interval * 24 * 60 * 60
      "w" -> int_interval * 7 * 24 * 60 * 60
      _ -> int_interval
    end
  end

  def valid_compound_duration?(value) do
    case Integer.parse(value) do
      {int, string} when is_integer(int) and string in ["ns", "s", "m", "h", "d", "w"] -> true
      _ -> false
    end
  end

  def from_erl(erl_datetime) do
    with {:ok, naive_dt} <- NaiveDateTime.from_erl(erl_datetime),
         {:ok, datetime} <- DateTime.from_naive(naive_dt, "Etc/UTC") do
      {:ok, datetime}
    end
  end

  def from_erl!(erl_datetime) do
    case from_erl(erl_datetime) do
      {:ok, datetime} -> datetime
      {:error, error} -> raise(error)
    end
  end

  def from_iso8601!(datetime_str) when is_binary(datetime_str) do
    {:ok, datetime, _} = DateTime.from_iso8601(datetime_str)
    datetime
  end

  def from_iso8601_to_unix!(datetime_str) do
    datetime_str
    |> from_iso8601!()
    |> DateTime.to_unix()
  end

  def valid_interval_string?(interval_string) when not is_binary(interval_string) do
    {:error, "The provided string #{interval_string} is not a valid string interval"}
  end

  def valid_interval_string?(interval_string) when is_binary(interval_string) do
    if Regex.match?(~r/^\d+[smhdw]{1}$/, interval_string) do
      true
    else
      {:error, "The provided string #{interval_string} is not a valid string interval"}
    end
  end
end
