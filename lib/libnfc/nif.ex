# SPDX-License-Identifier: Apache-2.0

defmodule LibNFC.NIF do
  @moduledoc false

  @on_load :on_load

  # The Makefile installs the shared object to `./priv` which corresponds to the priv dir
  # of the containing mix project.
  app = Mix.Project.config()[:app]

  def on_load do
    :ok =
      unquote(app)
      |> :code.priv_dir()
      |> :filename.join(~c"libnfc_nif")
      |> :erlang.load_nif(0)
  end

  def list_devices, do: not_loaded()
  def open, do: not_loaded()
  def open(_device), do: not_loaded()
  def version, do: not_loaded()
  def initiator_select_passive_target(_open_device, _modulation), do: not_loaded()
  def initiator_target_is_present(_open_device), do: not_loaded()

  defp not_loaded, do: :erlang.nif_error(:not_loaded)
end
