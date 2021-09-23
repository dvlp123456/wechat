defmodule WeChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  @app :wechat

  def start(_type, _args) do
    WeChat.Storage.Cache.init_table()
    config = Application.get_all_env(@app) |> normalize()
    config[:clients] |> List.wrap() |> setup_clients()

    children = [
      {Finch, name: WeChat.Finch, pools: %{:default => config[:finch_pool]}},
      {config[:refresher], config[:refresh_settings]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WeChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp normalize(config) do
    Keyword.merge(
      [
        finch_pool: [size: 32, count: 8],
        refresher: WeChat.Refresher.Default,
        refresh_settings: %{},
        clients: []
      ],
      config
    )
  end

  defp setup_clients(clients) do
    for {client, settings} <- clients, is_atom(client) do
      if match?(:work, client.app_type()) do
        setup_work_client(client, _agents = settings)
      else
        setup_client(client, settings)
      end
    end
  end

  defp setup_client(client, settings) do
    %{hub_springboard_url: hub_springboard_url, oauth2_callbacks: oauth2_callbacks} =
      replace_app(settings, client)

    # hub_springboard_url set for hub client
    if hub_springboard_url do
      WeChat.set_hub_springboard_url(client, hub_springboard_url)
    end

    # oauth2_callbacks set for hub server
    if oauth2_callbacks do
      for {env, url} <- oauth2_callbacks, is_binary(env) and is_binary(url) do
        WeChat.set_oauth2_env_url(client, env, url)
      end
    end
  end

  defp setup_work_client(client, %{all: settings}) do
    setup_work_client(client, all: settings)
  end

  defp setup_work_client(client, all: settings) do
    agents = Enum.map(client.agents(), fn %{id: id, name: name} -> {name || id, settings} end)
    setup_work_client(client, agents)
  end

  defp setup_work_client(client, agents) do
    for {agent, settings} <- agents do
      %{hub_springboard_url: hub_springboard_url, oauth2_callbacks: oauth2_callbacks} =
        settings |> replace_app(client) |> replace_agent(agent)

      # hub_springboard_url set for hub client
      if hub_springboard_url do
        WeChat.set_hub_springboard_url(client, agent, hub_springboard_url)
      end

      # oauth2_callbacks set for hub server
      if oauth2_callbacks do
        for {env, url} <- oauth2_callbacks, is_binary(env) and is_binary(url) do
          WeChat.set_oauth2_env_url(client, agent, env, url)
        end
      end
    end
  end

  defp replace_app(settings, client) do
    app = client.code_name()

    hub_springboard_url =
      if hub_springboard_url = settings[:hub_springboard_url] do
        String.replace(hub_springboard_url, ":app", app)
      end

    oauth2_callbacks =
      if oauth2_callbacks = settings[:oauth2_callbacks] do
        for {env, url} <- oauth2_callbacks, is_binary(env) and is_binary(url) do
          {env, String.replace(url, ":app", app)}
        end
      end

    %{hub_springboard_url: hub_springboard_url, oauth2_callbacks: oauth2_callbacks}
  end

  defp replace_agent(
         %{hub_springboard_url: hub_springboard_url, oauth2_callbacks: oauth2_callbacks},
         agent
       ) do
    agent = to_string(agent)

    hub_springboard_url =
      if hub_springboard_url do
        String.replace(hub_springboard_url, ":agent", agent)
      end

    oauth2_callbacks =
      if oauth2_callbacks do
        for {env, url} <- oauth2_callbacks do
          {env, String.replace(url, ":agent", agent)}
        end
      end

    %{hub_springboard_url: hub_springboard_url, oauth2_callbacks: oauth2_callbacks}
  end
end
