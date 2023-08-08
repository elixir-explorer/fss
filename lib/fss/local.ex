defmodule FSS.Local do
  defmodule Entry do
    defstruct [:path]

    @type t :: %__MODULE__{path: String.t()}
  end
end
