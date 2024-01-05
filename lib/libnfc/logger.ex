# SPDX-License-Identifier: Apache-2.0

defmodule LibNFC.Logger do
  @moduledoc """
  Sample logger implementation of `LibNFC.Presence` behaviour.
  """

  @moduledoc since: "0.1.0"

  use LibNFC.Presence
  require Logger

  @impl true
  def handle_target_in(target, state) do
    Logger.info("selected target: #{inspect(uid_hex(target))}")
    {:ok, state}
  end

  @impl true
  def handle_target_out(state) do
    Logger.info("target disappeared")
    {:ok, state}
  end
end
