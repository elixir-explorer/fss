defmodule FSS do
  # The initial work is from Explorer's code base.
  #
  # See https://github.com/elixir-explorer/explorer/pull/645
  # and the PRs that followed that one.

  @moduledoc """
  A small abstraction for file storage specifications.

  It's a library to parse and validate URIs, with the necessary
  attributes.

  See the supported specifications for more details:

  * `FSS.Local`
  * `FSS.HTTP`
  * `FSS.S3`
  """
end
