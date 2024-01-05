# SPDX-License-Identifier: Apache-2.0

defmodule LibNFC.Mock do
  @moduledoc """
  NFC device emulation for testing purposes without physical interaction with a NFC device.

  This module allows to emulate the presence of NFC targets in range of a "mock" device.
  `LibNFC.Mock` is a GenServer (to be spawned within a supervision tree) that holds the status
  of NFC targets in range. Functions on `LibNFC` accepting a `:mock` parameter instead of the
  NFC device reference will fetch data from this server instead of actually talking to libnfc.
  """

  @moduledoc since: "0.1.0"

  use GenServer

  @nif_delay_ms 400
  @nif_delay_jitter 0.5

  @type modulation :: atom
  @type target_info :: %{required(String.t()) => binary}

  @type target :: %{
          required(:modulation) => modulation,
          required(:target_info) => target_info
        }

  @typedoc """
  Server options

  * `nif_delay` emulates delay of NIF calls (default: #{@nif_delay_ms})
  * `nif_delay_jitter` jitter factor for delay (default: #{@nif_delay_jitter})
  """
  @type server_options :: [
          {:nif_delay, non_neg_integer | false}
          | {:nif_delay_jitter, non_neg_integer}
        ]

  @doc false
  @spec child_spec(server_options) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Starts the mock process.
  """
  @doc since: "0.1.0"
  @spec start_link() :: GenServer.on_start()
  @spec start_link(server_options) :: GenServer.on_start()
  def start_link(opts \\ []) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Puts a NFC target in range.
  """
  @doc since: "0.1.0"
  @spec put_target() :: :ok
  @spec put_target(target_info) :: :ok
  @spec put_target(target_info, modulation) :: :ok
  def put_target(target_info \\ %{"uid" => :rand.bytes(4)}, modulation \\ :iso14443a)

  def put_target(target_info, modulation) when is_binary(target_info) do
    put_target(%{"uid" => target_info}, modulation)
  end

  def put_target(target_info, modulation) when is_map(target_info) do
    GenServer.call(__MODULE__, {:put_target, {target_info, modulation}})
  end

  @doc """
  Removes the NFC target.
  """
  @doc since: "0.1.0"
  @spec clear_target() :: :ok
  def clear_target do
    GenServer.call(__MODULE__, :clear_target)
  end

  @doc false
  @spec initiator_select_passive_target(modulation) :: {:ok, target_info} | nil
  def initiator_select_passive_target(modulation) do
    GenServer.call(__MODULE__, {:select_target, modulation})
  end

  @doc false
  @spec initiator_target_is_present() :: integer()
  def initiator_target_is_present do
    GenServer.call(__MODULE__, :target_is_present)
  end

  @impl GenServer
  def init(opts) do
    {:ok, %{target: nil, selected: false, opts: opts}}
  end

  @impl GenServer
  def handle_call(msg, _from, %{opts: opts} = state) do
    {emulated_nif_call?, reply, new_state} =
      case {msg, state} do
        {{:put_target, {target_info, modulation}}, state} ->
          {false, :ok, %{state | target: %{target_info: target_info, modulation: modulation}}}

        {:clear_target, state} ->
          {false, :ok, %{state | target: nil}}

        {{:select_target, nm}, %{target: %{modulation: nm, target_info: tai}}} ->
          {true, tai, %{state | selected: true}}

        {{:select_target, _nm}, _nil_or_different_nm} ->
          {true, nil, state}

        {:target_is_present, %{target: target, selected: true}} when not is_nil(target) ->
          {true, 0, state}

        {:target_is_present, %{target: nil, selected: true}} ->
          {true, -2, %{state | selected: false}}

        {:target_is_present, _not_selected} ->
          {true, -10, state}
      end

    if emulated_nif_call? do
      emulate_nif_delay(opts)
    end

    {:reply, reply, new_state}
  end

  defp emulate_nif_delay(opts) do
    if nif_delay_ms = Keyword.get(opts, :nif_delay, @nif_delay_ms) do
      nif_delay_jitter = Keyword.get(opts, :nif_delay_jitter, @nif_delay_jitter)
      nif_delay_jitter = trunc(nif_delay_ms * nif_delay_jitter)

      Process.sleep(nif_delay_ms + :rand.uniform(nif_delay_jitter) - div(nif_delay_jitter, 2))
    end
  end
end
