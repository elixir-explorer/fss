defmodule FSS.S3 do
  @moduledoc """
  Specification for accessing AWS S3 resources.
  """

  defmodule Config do
    @moduledoc """
    Represents the configuration needed for accessing an S3 resource.
    """

    defstruct [
      :access_key_id,
      :bucket,
      :region,
      :secret_access_key,
      :endpoint,
      :token
    ]

    @typedoc """
    The configuration struct for S3.

    The attributes are:

    * `:access_key_id` - This attribute is required.
    * `:bucket` - A valid bucket name. This attribute is required.
    * `:region` - This attribute is required.
    * `:secret_access_key` - This attribute is required.
    * `:endpoint` - This attribute is optional. If specified, then `:region` is ignored.
      This attribute is useful for when you are using a service that is compatible with
      the AWS S3 API.
    * `:token` - This attribute is optional.
    """
    @type t :: %__MODULE__{
            access_key_id: String.t(),
            bucket: String.t(),
            region: String.t(),
            secret_access_key: String.t(),
            endpoint: String.t() | nil,
            token: String.t() | nil
          }
  end

  defmodule Entry do
    @moduledoc """
    Represents the S3 resource itself.
    """

    defstruct [:key, :config]

    @typedoc """
    The entry struct for S3.

    The attributes are:

    * `:key` - A valid key for the resource. This attribute is required.
    * `:config` - A valid S3 config from the type `Config.t()`. This attribute is required.
    """
    @type t :: %__MODULE__{
            key: String.t(),
            config: Config.t()
          }
  end

  @doc """
  Parses a URL in the format `s3://bucket/resource-key`.

  ## Options

    * `:config` - It expects a `Config.t()` or a `Keyword.t()` with the keys
      representing the attributes of the `Config.t()`. By default it is `nil`,
      which means that we are going to try to fetch the credentials and configuration
      from the system's environment variables.

      The following env vars are read:

      - `AWS_ACCESS_KEY_ID`
      - `AWS_SECRET_ACCESS_KEY`
      - `AWS_REGION` or `AWS_DEFAULT_REGION`
      - `AWS_SESSION_TOKEN`

      Although you can pass the `:bucket` as a configuration option, it's not
      possible to override the bucket name from the URL.
  """
  @spec parse(String.t(), Keyword.t()) :: {:ok, Entry.t()} | {:error, Exception.t()}
  def parse(url, opts \\ []) do
    opts = Keyword.validate!(opts, config: nil)

    uri = URI.parse(url)

    case uri do
      %{scheme: "s3", host: bucket, path: "/" <> key} when is_binary(bucket) ->
        config =
          opts
          |> Keyword.fetch!(:config)
          |> normalize_config!()
          |> validate_config!()

        {:ok, %Entry{key: key, config: %{config | bucket: bucket}}}

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

  defp normalize_config!(nil), do: config_from_system_env()
  defp normalize_config!(%Config{} = config), do: config

  defp normalize_config!(config) when is_list(config) or is_map(config) do
    struct!(config_from_system_env(), config)
  end

  defp normalize_config!(other) do
    raise ArgumentError,
          "expect configuration to be a %FSS.S3.Config{} struct, a keyword list or a map. Instead got #{inspect(other)}"
  end

  defp check!(config, key, env) do
    if Map.fetch!(config, key) in ["", nil] do
      raise ArgumentError,
            "missing #{inspect(key)} for FSS.S3 (set the key or the #{env} env var)"
    end
  end

  @doc """
  Builds a `Config.t()` reading from the system env.
  """
  @spec config_from_system_env :: Config.t()
  def config_from_system_env() do
    %Config{
      access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
      region: System.get_env("AWS_REGION", System.get_env("AWS_DEFAULT_REGION")),
      token: System.get_env("AWS_SESSION_TOKEN")
    }
  end

  @doc """
  Parses configuration from a bucket URL.

  It expects an URL in the following formats:

  - `https://s3.[region].amazonaws.com/[bucket]`
  - `https://[bucket].s3.[region].amazonaws.com`
  - `https://my-custom-endpoint.com/[bucket]`

  If the URL is not in one of these formats, then an error
  is returned. For custom endpoints (services that are compatible
  with AWS S3), it's possible to pass the port and use HTTP.

  All the additional required configuration must be passed as
  options to the `:config` option.

  ## Options

    * `:config` - It expects a `Config.t()` or a `Keyword.t()` with the keys
      representing the attributes of the `Config.t()`. By default it is `nil`,
      which means that we are going to try to fetch the credentials and configuration
      from the system's environment variables.

      The following env vars are read:

      - `AWS_ACCESS_KEY_ID`
      - `AWS_SECRET_ACCESS_KEY`
      - `AWS_REGION` or `AWS_DEFAULT_REGION`
      - `AWS_SESSION_TOKEN`

      Although you can pass the `:bucket` and `:region` as options,
      they are always override by the values parsed from the URL.
  """
  @spec parse_config_from_bucket_url(String.t()) :: {:ok, Config.t()} | {:error, Exception.t()}
  def parse_config_from_bucket_url(bucket_url, opts \\ []) do
    opts = Keyword.validate!(opts, config: nil)

    uri = URI.parse(bucket_url)

    case uri do
      %{host: host, path: path} when is_binary(host) and (is_nil(path) or path == "/") ->
        base_config =
          opts
          |> Keyword.fetch!(:config)
          |> normalize_config!()

        case String.split(host, ".") do
          [bucket, "s3", region, "amazonaws", "com"] ->
            {:ok, %Config{base_config | bucket: bucket, region: region}}

          _other ->
            {:error,
             ArgumentError.exception(
               "cannot extract bucket name from URL. Expected URL in the format " <>
                 "https://s3.[region].amazonaws.com/[bucket], got: " <>
                 URI.to_string(uri)
             )}
        end

      %{host: host, path: "/" <> bucket} when is_binary(host) ->
        base_config =
          opts
          |> Keyword.fetch!(:config)
          |> normalize_config!()
          |> then(fn config -> %Config{config | bucket: bucket} end)

        case String.split(host, ".") do
          ["s3", region, "amazonaws", "com"] ->
            {:ok, %Config{base_config | region: region}}

          _other ->
            endpoint_uri = %URI{uri | path: nil}

            {:ok, %Config{base_config | endpoint: URI.to_string(endpoint_uri)}}
        end

      _ ->
        {:error,
         ArgumentError.exception(
           "expected URL in the format " <>
             "https://s3.[region].amazonaws.com/[bucket], got: " <>
             URI.to_string(uri)
         )}
    end
  end
end
