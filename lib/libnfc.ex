# SPDX-License-Identifier: Apache-2.0

defmodule LibNFC do
  @readme Path.join([__DIR__, "../README.md"])
  @external_resource @readme
  @moduledoc @readme
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.drop(1)
             |> Enum.take_every(2)
             |> Enum.join("\n")

  @moduledoc since: "0.1.0"

  alias LibNFC.{Mock, NIF}

  @typedoc """
  Reference of opened NFC device.
  """
  @type device :: reference | :mock

  @typedoc """
  Short identifier for types of NFC targets. Defines both modulation & baud rate.

  See `nfc_baud_rate` and `nfc_modulation_type` in [`nfc_types.h`](http://www.libnfc.org/api/nfc-types_8h_source.html).

  ## Known types

  - `:iso14443a` -> `NMT_ISO14443A`, `NBR_106`
  """
  @type modulation :: atom

  @typedoc """
  Map of data received from NFC target.

  Structure is determined by NFC target type.

  See `nfc_target_info` union in [`nfc_types.h`](http://www.libnfc.org/api/nfc-types_8h_source.html).
  """
  @type target_info :: %{required(String.t()) => binary}

  @doc """
  Lists NFC devices controlled by operating system.
  """
  @doc since: "0.1.0"
  @spec list_devices() :: [String.t()]
  def list_devices do
    Enum.map(NIF.list_devices(), &to_string/1)
  end

  @doc """
  Opens the default NFC device.
  """
  @doc since: "0.1.0"
  @spec open() :: [device]
  def open do
    NIF.open()
  end

  @doc """
  Opens a specific NFC device identified by a "connstring".
  """
  @doc since: "0.1.0"
  @spec open(String.t()) :: [device]
  def open(device) when is_binary(device) do
    NIF.open(String.to_charlist(device))
  end

  @doc """
  Tries to select a passive target with a given modulation.
  """
  @doc since: "0.1.0"
  @spec initiator_select_passive_target(device) :: nil | {:ok, target_info} | :error
  @spec initiator_select_passive_target(device, modulation) :: nil | {:ok, target_info} | :error
  def initiator_select_passive_target(open_device, modulation \\ :iso14443a)

  def initiator_select_passive_target(:mock, modulation) do
    Mock.initiator_select_passive_target(modulation)
  end

  def initiator_select_passive_target(open_device, modulation) do
    if target_info = NIF.initiator_select_passive_target(open_device, modulation) do
      Map.new(target_info, fn {k, v} -> {to_string(k), v} end)
    end
  end

  @doc """
  Checks whether a previously selected target is still present.
  """
  @doc since: "0.1.0"
  @spec initiator_target_is_present?(device) :: boolean
  def initiator_target_is_present?(:mock) do
    Mock.initiator_target_is_present() == 0
  end

  def initiator_target_is_present?(open_device) do
    NIF.initiator_target_is_present(open_device) == 0
  end

  @doc """
  Returns version of linked libnfc library.
  """
  @doc since: "0.1.0"
  @spec version() :: String.t()
  def version do
    to_string(NIF.version())
  end
end
