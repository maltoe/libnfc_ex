# SPDX-License-Identifier: Apache-2.0

defmodule LibNFC.Utils do
  @moduledoc """
  Utilities for working with NFC targets.
  """

  @moduledoc since: "0.1.0"

  @doc """
  Returns hexadecimal representation of UID of a NFC target.
  """
  @doc since: "0.1.0"
  @spec uid_hex(map | binary) :: binary
  def uid_hex(%{"uid" => uid}), do: uid_hex(uid)
  def uid_hex(uid) when is_binary(uid), do: Base.encode16(uid, case: :lower)
end
