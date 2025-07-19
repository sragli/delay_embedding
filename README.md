# DelayEmbedding

Elixir module for computing delay embedding of time series data.

Delay embedding is a technique used in dynamical systems analysis to reconstruct the state space of a system from a single time series. It creates a higher-dimensional representation by using time-delayed versions of the original signal.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `delay_embedding` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:delay_embedding, "~> 0.1.0"}
  ]
end
```

## Functions

* *embed/3* - Main function for computing delay embedding with specified parameters
* *embed_auto/2* - Automatic parameter estimation for convenience

## Key features

* Delay Embedding: Creates embedded vectors by taking time-delayed coordinates from the original time series
* Automatic Parameter Estimation:
  * Embedding dimension using a heuristic based on data length
  * Delay estimation using autocorrelation analysis
* Autocorrelation Analysis: Computes autocorrelation to find optimal delay
* Validation: Ensures parameters are compatible with data length

## Usage

```elixir
# Basic usage with specified parameters
DelayEmbedding.embed([1, 2, 3, 4, 5, 6], 3, 1)
# Returns: [[1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6]]

# Automatic parameter estimation
DelayEmbedding.embed_auto([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

# Validate parameters before embedding
DelayEmbedding.validate_parameters(data, 3, 2)
```

The module is designed to be efficient and handles edge cases gracefully. For production use with large datasets, you might want to consider using more sophisticated parameter estimation methods like False Nearest Neighbors for embedding dimension or Mutual Information for delay estimation.