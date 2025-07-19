defmodule DelayEmbeddingTest do
  use ExUnit.Case
  doctest DelayEmbedding

  test "calculates correct result" do
    assert [[1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6]] =
             DelayEmbedding.embed([1, 2, 3, 4, 5, 6], 3, 1)
  end
end
