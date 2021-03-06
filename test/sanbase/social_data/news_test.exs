defmodule Sanbase.NewsTest do
  use SanbaseWeb.ConnCase, async: false

  import Mockery
  import ExUnit.CaptureLog

  alias Sanbase.SocialData

  setup do
    [
      from: DateTime.from_naive!(~N[2018-04-16 10:00:00], "Etc/UTC"),
      to: DateTime.from_naive!(~N[2018-04-16 22:00:00], "Etc/UTC")
    ]
  end

  describe "google_news/4" do
    test "response: success", context do
      success_response = ~s([
        {
          "timestamp": "2018-04-16T10:00:00Z",
          "description": "test description",
          "title": "test title",
          "url": "http://example.com",
          "source_name": "ForexTV.com",
          "media_url": "http://test"
        }
      ])

      mock(
        HTTPoison,
        :get,
        {:ok,
         %HTTPoison.Response{
           body: success_response,
           status_code: 200
         }}
      )

      result = SocialData.google_news("BTC", context.from, context.to, 2)

      assert result ==
               {:ok,
                [
                  %{
                    datetime: Sanbase.DateTimeUtils.from_iso8601!("2018-04-16T10:00:00Z"),
                    description: "test description",
                    media_url: "http://test",
                    source_name: "ForexTV.com",
                    title: "test title",
                    url: "http://example.com"
                  }
                ]}
    end

    test "when media_link is empty string - converts to nil", context do
      success_response = ~s([
        {
          "timestamp": "2018-04-16T10:00:00Z",
          "description": "test description",
          "title": "test title",
          "url": "http://example.com",
          "source_name": "ForexTV.com",
          "media_url": ""
        }
      ])

      mock(
        HTTPoison,
        :get,
        {:ok,
         %HTTPoison.Response{
           body: success_response,
           status_code: 200
         }}
      )

      result = SocialData.google_news("BTC", context.from, context.to, 2)

      assert result ==
               {:ok,
                [
                  %{
                    datetime: Sanbase.DateTimeUtils.from_iso8601!("2018-04-16T10:00:00Z"),
                    description: "test description",
                    media_url: nil,
                    source_name: "ForexTV.com",
                    title: "test title",
                    url: "http://example.com"
                  }
                ]}
    end

    test "when there are no mentions in the news for this tag", context do
      mock(
        HTTPoison,
        :get,
        {:ok,
         %HTTPoison.Response{
           body: "[]",
           status_code: 200
         }}
      )

      result = SocialData.google_news("TAG no mentions", context.from, context.to, 2)

      assert result == {:ok, []}
    end

    test "response: 404", context do
      mock(
        HTTPoison,
        :get,
        {:ok,
         %HTTPoison.Response{
           body: "Some message",
           status_code: 404
         }}
      )

      tag = "Not existing"

      result = fn ->
        SocialData.google_news(tag, context.from, context.to, 2)
      end

      assert capture_log(result) =~
               "Error status 404 fetching news for tag #{tag}"
    end

    test "response: error", context do
      mock(
        HTTPoison,
        :get,
        {:error,
         %HTTPoison.Error{
           reason: :econnrefused
         }}
      )

      tag = "Not existing"

      result = fn ->
        SocialData.google_news(tag, context.from, context.to, 2)
      end

      assert capture_log(result) =~
               "Cannot fetch news data for tag #{tag}: :econnrefused\n"
    end
  end
end
