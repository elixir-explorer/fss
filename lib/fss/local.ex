defmodule FSS.Local do
  @moduledoc """
  A module for representing local files.

  The `FSS.Local.Entry` represents a local file with its path.
  """

  defmodule Entry do
    defstruct [:path]

    @moduledoc """
    Represents a local file.
    """

    @typedoc """
    The only attribute is the `:path` to a local file.
    """
    @type t :: %__MODULE__{path: String.t()}
  end
end
