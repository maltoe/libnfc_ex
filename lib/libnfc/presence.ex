# SPDX-License-Identifier: Apache-2.0

defmodule LibNFC.Presence do
  @moduledoc """
  Passive tag monitor process.

  - Repeatedly polls for passive targets in range.
  - Emits an event when target enters.
  - Emits another event when target leaves.

  Target presence is tracked by polling `nfc_initiator_target_is_present` with a short debounce.

  ## Usage

      defmodule MyApp.NFC do
        use LibNFC.Presence

        @impl true
        def handle_target_in(target, state) do
          # ...
          {:ok, state}
        end

        @impl true
        def handle_target_out(state) do
          # ...
          {:ok, state}
        end
      end

      defmodule MyApp.Application do
        def start(_, _) do
          children = [
            ...
            {MyApp.NFC, client_state: :foo}
          ]

          Supervisor.start_link(...)
        end
      end
  """

  @moduledoc since: "0.1.0"

  use GenServer

  @schedule_delay_ms 300
  @alive_after_last_seen_ms 500

  @typedoc """
  Arbitrary client state held within the presence monitor process.
  """
  @type client_state :: any

  @typedoc """
  Server Options

  * `client_state` initial client state (default: nil)
  * `mock` when set to true, default device will be the mock (default: false)
  * `schedule_delay` poll interval in ms (default: #{@schedule_delay_ms})
  * `alive_after_last_seen` debounce leave event for a short period as some calls to
    `nfc_initiator_target_is_present` come back as false negatives (default: #{@alive_after_last_seen_ms})
  """
  @type server_options :: [
          {:client_state, client_state}
          | {:mock, boolean}
          | {:schedule_delay, non_neg_integer}
          | {:alive_after_last_seen, non_neg_integer}
        ]

  @doc """
  Called on process initialization to open the NFC reader device.

  Optional callback. Defaults to opening the "first" device found by calling `nfc_open` without
  a connstring.
  """
  @doc since: "0.1.0"
  @callback open_device(client_state) :: {:ok, LibNFC.device()}

  @doc """
  Emitted when a passive target is detected.
  """
  @doc since: "0.1.0"
  @callback handle_target_in(LibNFC.target_info(), client_state) :: {:ok, client_state}

  @doc """
  Emitted when selected target left.
  """
  @doc since: "0.1.0"
  @callback handle_target_out(client_state) :: {:ok, client_state}

  @optional_callbacks open_device: 1

  defmacro __using__(_) do
    quote do
      import LibNFC.Utils

      @behaviour LibNFC.Presence

      @spec child_spec(LibNFC.Presence.server_options()) :: Supervisor.child_spec()
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @spec start_link(LibNFC.Presence.server_options()) :: GenServer.on_start()
      def start_link(opts \\ []) do
        LibNFC.Presence.start_link(__MODULE__, opts)
      end
    end
  end

  @doc """
  Starts the passive tag monitor process.
  """
  @doc since: "0.1.0"
  @spec start_link(module, server_options) :: GenServer.on_start()
  def start_link(client, opts) when is_atom(client) and is_list(opts) do
    GenServer.start_link(__MODULE__, {client, opts})
  end

  @impl true
  def init({client, opts}) when is_atom(client) do
    {client_state, opts} = Keyword.pop(opts, :client_state)

    {:ok, ref} =
      cond do
        function_exported?(client, :open_device, 1) ->
          client.open_device(client_state)

        Keyword.get(opts, :mock) ->
          {:ok, :mock}

        true ->
          LibNFC.open()
      end

    schedule(0, opts)

    {:ok, %{client: client, client_state: client_state, ref: ref, opts: opts, scan: :idle}}
  end

  @impl true
  def handle_info({:run, n}, %{opts: opts, scan: :idle} = state) do
    state =
      case LibNFC.initiator_select_passive_target(state.ref) do
        nil ->
          state

        target ->
          :handle_target_in
          |> callback([target], state)
          |> select(target)
      end

    schedule(n, opts)

    {:noreply, state}
  end

  def handle_info({:run, n}, %{opts: opts, scan: {:selected, target, last_seen}} = state) do
    state =
      cond do
        LibNFC.initiator_target_is_present?(state.ref) ->
          select(state, target)

        consider_alive?(last_seen, opts) ->
          state

        true ->
          :handle_target_out
          |> callback([], state)
          |> Map.put(:scan, :idle)
      end

    schedule(n, opts)

    {:noreply, state}
  end

  defp schedule(prev, opts) do
    schedule_delay_ms = Keyword.get(opts, :schedule_delay, @schedule_delay_ms)

    Process.send_after(self(), {:run, prev + 1}, schedule_delay_ms)
  end

  defp callback(which, args, state) do
    {:ok, new_client_state} =
      apply(state.client, which, args ++ [state.client_state])

    %{state | client_state: new_client_state}
  end

  defp select(state, target) do
    %{state | scan: {:selected, target, now()}}
  end

  defp now, do: DateTime.utc_now()

  defp consider_alive?(last_seen, opts) do
    alive_after_last_seen_ms =
      Keyword.get(opts, :alive_after_last_seen, @alive_after_last_seen_ms)

    DateTime.diff(now(), last_seen, :microsecond) < alive_after_last_seen_ms * 1000
  end
end
