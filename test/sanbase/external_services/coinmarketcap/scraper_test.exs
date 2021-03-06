defmodule Sanbase.ExternalServices.Coinmarketcap.ScraperTest do
  use Sanbase.DataCase, async: false

  alias Sanbase.ExternalServices.Coinmarketcap.Scraper
  alias Sanbase.ExternalServices.ProjectInfo

  test "parsing the project page" do
    project_info =
      File.read!(Path.join(__DIR__, "data/project_page.html"))
      |> Scraper.parse_project_page(%ProjectInfo{slug: "santiment"})

    assert project_info == %ProjectInfo{
             slug: "santiment",
             name: "Santiment Network Token",
             ticker: "SAN",
             website_link: "https://santiment.net/",
             github_link: "https://github.com/santiment",
             main_contract_address: "0x7c5a0ce9267ed19b22f8cae653f198e3e8daf098",
             etherscan_token_name: "SAN"
           }
  end
end
