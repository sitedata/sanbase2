defmodule Sanbase.Signal.OperationText.KV do
  @moduledoc ~s"""
  A module providing a single function to_template_kv/3 which transforms an operation
  to human readable text that can be included in the signal's payload
  """
  def to_template_kv(value, operation, opts \\ [])

  # Above
  def to_template_kv(%{current: value}, %{above: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(value, %{above: above}, opts) do
    form = Keyword.get(opts, :form, :singular)
    template = "#{form_to_text(form)} above {{above}} and #{form_to_text(form)} now {{value}}"
    kv = %{above: above, value: value}
    {template, kv}
  end

  # Below
  def to_template_kv(%{current: value}, %{below: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(value, %{below: below}, opts) do
    form = Keyword.get(opts, :form, :singular) |> form_to_text()

    template = "#{form} below {{below}} and #{form} now {{value}}"
    kv = %{below: below, value: value}
    {template, kv}
  end

  # Inside channel
  def to_template_kv(%{current: value}, %{inside_channel: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(value, %{inside_channel: [lower, upper]}, opts) do
    form = Keyword.get(opts, :form, :singular) |> form_to_text()

    template = "#{form} inside the [{{lower}}, {{upper}}] interval and #{form} now {{value}}"
    kv = %{lower: lower, upper: upper, value: value}
    {template, kv}
  end

  # Outside channel
  def to_template_kv(%{current: value}, %{outside_channel: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(value, %{outside_channel: [lower, upper]}, opts) do
    form = Keyword.get(opts, :form, :singular) |> form_to_text()

    template = "#{form} outside the [{{lower}}, {{upper}}] interval and #{form} now {{value}}"
    kv = %{lower: lower, upper: upper, value: value}
    {template, kv}
  end

  # Percent up
  def to_template_kv(%{percent_change: value}, %{percent_up: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(percent_change, %{percent_up: _percent}, _opts) do
    template = "increased by {{percent_change}}%"
    kv = %{percent_change: percent_change}
    {template, kv}
  end

  # Percent down
  def to_template_kv(%{percent_change: value}, %{percent_down: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(percent_change, %{percent_down: _percent}, _opts) do
    template = "decreased by {{percent_change}}%"
    kv = %{percent_change: abs(percent_change)}
    {template, kv}
  end

  # Amount up
  def to_template_kv(%{absolute_change: value}, %{amount_up: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(amount_changed, %{amount_up: _amount}, _opts) do
    template = "increased by {{amount_changed}}%"
    kv = %{amount_changed: amount_changed}
    {template, kv}
  end

  # Amount
  def to_template_kv(%{absolute_change: value}, %{amount_down: _} = op, opts),
    do: to_template_kv(value, op, opts)

  def to_template_kv(amount_changed, %{amount_down: _amount}, _opts) do
    template = "decreased by {{amount_changed}}%"
    kv = %{amount_changed: abs(amount_changed)}
    {template, kv}
  end

  def to_template_kv(_, %{all_of: operations}, _opts) when is_list(operations) do
    {"not implemented", %{}}
  end

  def to_template_kv(_, %{none_of: operations}, _opts) when is_list(operations) do
    {"not implemented", %{}}
  end

  def to_template_kv(_, %{some_of: operations}, _opts) when is_list(operations) do
    {"not implemented", %{}}
  end

  # Private functions

  defp form_to_text(:singular), do: "is"
  defp form_to_text(:plural), do: "are"
end