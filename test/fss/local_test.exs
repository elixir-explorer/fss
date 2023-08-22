defmodule FSS.LocalTest do
  use ExUnit.Case, async: true

  doctest FSS.Local

  test "from_path/1" do
    path = "/home/joe/file.txt"
    assert %FSS.Local.Entry{path: ^path} = FSS.Local.from_path(path)
  end
end
