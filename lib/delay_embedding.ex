defmodule DelayEmbedding do
  @moduledoc """
  Module for computing delay embedding of time series data.
  """

  @doc """
  Computes the delay embedding of a time series.

  ## Parameters
  - `data`: List of numerical values representing the time series
  - `embedding_dimension`: Integer, the dimension of the embedding space (m)
  - `delay`: Integer, the time delay (tau) between coordinates

  ## Returns
  A list of embedded vectors, where each vector is a list of `embedding_dimension` values.
  """
  @spec embed(list(), pos_integer(), pos_integer()) :: list()
  def embed(data, embedding_dimension, delay) when embedding_dimension > 0 and delay > 0 do
    data_length = length(data)

    # Calculate the number of embedded vectors we can create
    num_vectors = data_length - (embedding_dimension - 1) * delay

    if num_vectors <= 0 do
      []
    else
      # Convert list to indexed map for efficient random access
      indexed_data =
        data
        |> Enum.with_index()
        |> Map.new(fn {val, idx} -> {idx, val} end)

      # Generate embedded vectors
      for i <- 0..(num_vectors - 1) do
        for j <- 0..(embedding_dimension - 1) do
          Map.get(indexed_data, i + j * delay)
        end
      end
    end
  end

  @doc """
  Computes delay embedding with automatic parameter estimation.

  Uses simple heuristics to estimate embedding dimension and delay if not provided.

  ## Parameters
  - `data`: List of numerical values representing the time series
  - `opts`: Keyword list with optional parameters:
    - `:embedding_dimension` - If not provided, uses a heuristic based on data length
    - `:delay` - If not provided, estimates using first minimum of autocorrelation

  ## Returns
  Embedding with estimated parameters.
  """
  @spec embed_auto(list()) :: list()
  def embed_auto(data, opts \\ []) when is_list(data) do
    embedding_dimension = opts[:embedding_dimension] || estimate_embedding_dimension(data)
    delay = opts[:delay] || estimate_delay(data)

    embed(data, embedding_dimension, delay)
  end

  @doc """
  Validates that the embedding parameters are feasible for the given data.
  """
  @spec validate_parameters(list(), pos_integer(), pos_integer()) ::
          :ok | {:error, <<_::64, _::_*8>>}
  def validate_parameters(data, embedding_dimension, delay) do
    data_length = length(data)
    required_length = (embedding_dimension - 1) * delay + 1

    cond do
      data_length < required_length ->
        {:error,
         "Data length (#{data_length}) is insufficient for embedding dimension #{embedding_dimension} and delay #{delay}. Need at least #{required_length} points."}

      embedding_dimension < 1 ->
        {:error, "Embedding dimension must be positive"}

      delay < 1 ->
        {:error, "Delay must be positive"}

      true ->
        :ok
    end
  end

  @doc """
  Estimates the embedding dimension using a simple heuristic.
  This is a basic implementation. For more sophisticated estimation,
  consider implementing methods like False Nearest Neighbors.
  """
  @spec estimate_embedding_dimension(list()) :: integer()
  def estimate_embedding_dimension(data) do
    # Simple heuristic: use 2 * log10(N) where N is data length
    data_length = length(data)
    max(2, round(2 * :math.log10(data_length)))
  end

  @doc """
  Estimates the delay using autocorrelation analysis.
  Finds the first minimum of the autocorrelation function as an estimate for delay.
  """
  @spec estimate_delay(list()) :: pos_integer() | nil
  def estimate_delay(data) do
    # Limit search to reasonable range
    max_lag = min(Integer.floor_div(length(data), 4), 50)

    autocorrelations =
      for lag <- 1..max_lag do
        {lag, autocorrelation(data, lag)}
      end

    find_first_minimum(autocorrelations) || 1
  end

  @doc """
  Computes the autocorrelation of a time series at a given lag.
  """
  @spec autocorrelation(list(), non_neg_integer()) :: float()
  def autocorrelation(data, lag) when lag < length(data), do: 0.0

  def autocorrelation(data, lag) do
    n = length(data) - lag
    mean_val = Enum.sum(data) / length(data)

    # Compute lagged covariance
    covariance =
      data
      |> Enum.take(n)
      |> Enum.zip(Enum.drop(data, lag))
      |> Enum.map(fn {x, y} -> (x - mean_val) * (y - mean_val) end)
      |> Enum.sum()
      |> Kernel./(n)

    # Compute variance
    variance =
      data
      |> Enum.map(fn x -> (x - mean_val) * (x - mean_val) end)
      |> Enum.sum()
      |> Kernel./(length(data))

    if variance == 0, do: 0.0, else: covariance / variance
  end

  @doc """
  Computes the correlation dimension using the Grassberger-Procaccia algorithm.
  This is a simplified version.
  """
  def correlation_dimension(embedded_data, max_radius \\ 1.0, n_radii \\ 20) do
    n_points = length(embedded_data)

    if n_points < 2 do
      0.0
    else
      radii = for i <- 1..n_radii, do: max_radius * i / n_radii

      correlations = Enum.map(radii, fn r ->
        count = count_pairs_within_radius(embedded_data, r)
        correlation = count / (n_points * (n_points - 1) / 2)
        {r, max(correlation, 1.0e-10)}  # Avoid log(0)
      end)

      # Fit line to log-log plot to estimate dimension
      estimate_slope(correlations)
    end
  end

  defp count_pairs_within_radius(embedded_data, radius) do
    embedded_data
    |> Enum.with_index()
    |> Enum.map(fn {point1, i} ->
      embedded_data
      |> Enum.drop(i + 1)
      |> Enum.count(fn point2 -> euclidean_distance(point1, point2) < radius end)
    end)
    |> Enum.sum()
  end

  defp euclidean_distance(point1, point2) do
    point1
    |> Enum.zip(point2)
    |> Enum.map(fn {x, y} -> (x - y) * (x - y) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  defp estimate_slope(correlations) do
    log_data = Enum.map(correlations, fn {r, c} -> {:math.log(r), :math.log(c)} end)

    n = length(log_data)
    sum_x = Enum.sum(Enum.map(log_data, fn {x, _} -> x end))
    sum_y = Enum.sum(Enum.map(log_data, fn {_, y} -> y end))
    sum_xy = Enum.sum(Enum.map(log_data, fn {x, y} -> x * y end))
    sum_x2 = Enum.sum(Enum.map(log_data, fn {x, _} -> x * x end))

    if n * sum_x2 - sum_x * sum_x == 0 do
      0.0
    else
      (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    end
  end

  defp find_first_minimum([]), do: nil
  defp find_first_minimum([{lag, _}]), do: lag

  defp find_first_minimum([{_lag1, val1}, {lag2, val2} | rest]) do
    if val1 > val2 do
      find_first_minimum([{lag2, val2} | rest])
    else
      case rest do
        [] ->
          lag2

        [{_lag3, val3} | _] ->
          if val2 < val3, do: lag2, else: find_first_minimum([{lag2, val2} | rest])
      end
    end
  end
end
