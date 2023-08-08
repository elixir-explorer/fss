defmodule FSS.HTTP do
  defmodule Config do
    defstruct [:headers]

    @type t :: %__MODULE__{headers: [{String.t(), String.t()}]}
  end

  defmodule Entry do
    defstruct [:url, :config]

    @type t :: %__MODULE__{url: String.t(), config: Config.t()}
  end

  def parse(url, opts \\ []) do
    opts = Keyword.validate!(opts, config: nil)

    with {:ok, config} <- build_config(opts[:config]) do
      {:ok, %Entry{url: url, config: config}}
    end
  end

  defp build_config(nil), do: {:ok, %Config{headers: []}}
  defp build_config(%Config{} = config), do: {:ok, config}

  defp build_config(config) when is_list(config) do
    case Keyword.validate(config, headers: []) do
      {:ok, opts} ->
        callback = fn pair ->
          match?({key, value} when is_binary(key) and is_binary(value), pair)
        end

        if Enum.all?(opts[:headers], callback) do
          {:ok, %Config{headers: opts[:headers]}}
        else
          {:error,
           ArgumentError.exception(
             "one of the headers is invalid. Expecting a list of `{\"key\", \"value\"}`, but got: #{inspect(opts[:headers])}"
           )}
        end

      {:error, key} ->
        {:error,
         ArgumentError.exception(
           "the keys #{inspect(key)} are not valid keys for the HTTP configuration"
         )}
    end
  end

  defp build_config(other) do
    {:error,
     ArgumentError.exception(
       "config for HTTP entry is invalid. Expecting `:headers`, but got #{inspect(other)}"
     )}
  end
end
