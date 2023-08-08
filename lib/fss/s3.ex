defmodule FSS.S3 do
  defmodule Config do
    defstruct [
      :access_key_id,
      :region,
      :secret_access_key,
      :endpoint,
      :token
    ]

    @type t :: %__MODULE__{
            access_key_id: String.t(),
            region: String.t(),
            secret_access_key: String.t(),
            endpoint: String.t() | nil,
            token: String.t() | nil
          }
  end

  defmodule Entry do
    defstruct [:bucket, :key, :config]

    @type t :: %__MODULE__{
            bucket: String.t(),
            key: String.t(),
            config: Config.t()
          }
  end

  def parse(url, opts \\ []) do
    opts = Keyword.validate!(opts, config: nil)

    uri = URI.parse(url)

    case uri do
      %{scheme: "s3", host: bucket, path: "/" <> key} when is_binary(bucket) ->
        config =
          opts
          |> Keyword.fetch!(:config)
          |> case do
            nil ->
              config_from_system_env()

            %Config{} = config ->
              config

            config when is_list(config) or is_map(config) ->
              struct!(config_from_system_env(), config)

            other ->
              raise ArgumentError,
                    "expect configuration to be a %FSS.S3.Config{} struct, a keyword list or a map. Instead got #{inspect(other)}"
          end
          |> validate_config!()

        {:ok, %Entry{bucket: bucket, key: key, config: config}}

      _ ->
        {:error,
         ArgumentError.exception(
           "expected s3://<bucket>/<key> URL, got: " <>
             URI.to_string(uri)
         )}
    end
  end

  defp validate_config!(%Config{} = config) do
    check!(config, :access_key_id, "AWS_ACCESS_KEY_ID")
    check!(config, :secret_access_key, "AWS_SECRET_ACCESS_KEY")
    check!(config, :region, "AWS_REGION")

    config
  end

  defp check!(config, key, env) do
    if Map.fetch!(config, key) in ["", nil] do
      raise ArgumentError,
            "missing #{inspect(key)} for FSS.S3 (set the key or the #{env} env var)"
    end
  end

  def config_from_system_env() do
    %Config{
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      region: System.get_env("AWS_REGION", System.get_env("AWS_DEFAULT_REGION")),
      token: System.get_env("AWS_SESSION_TOKEN")
    }
  end
end
