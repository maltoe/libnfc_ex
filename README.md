<!-- SPDX-License-Identifier: Apache-2.0 -->

# `libnfc_ex`

<!-- MDOC -->

This package provides a NIF binding to [libnfc](http://www.libnfc.org/) and some Elixir
boilerplate for convenient & more idiomatic use.

## Status

This library was designed to detect and track the presence of ISO/IEC 14443 Type A **passive NFC targets** from an Elixir application. Its original use-case was a Raspberry-based [music box](https://phoniebox.de/) controlled by cheap passive NFC tags detectable by a [PN532 NFC HAT](https://www.waveshare.com/wiki/PN532_NFC_HAT). The adaptation of libnfc functions as well as design of the surrounding Elixir API is so far limited to support this use-case, yet extending the library for other NFC modulations should be relatively straightforward.

- ✅ Listing & opening NFC devices
- ✅ ISO 14333 Type A passive target selecting & tracking

Not implemented:

- Other modulations
- Initiator API: Polling, writing, transceiving
- Target API

## Dependencies

- libnfc
- make
- working C11 compiler, e.g. gcc

### Installing libnfc from source

On Debian and derived Linux systems:

```
sudo apt-get install build-essentials automake autoconf
sudo apt-get install libusb-dev
```

```
git clone https://github.com/nfc-tools/libnfc
cd libnfc
autoreconf -vis
./configure --prefix=/usr --sysconfdir=/etc
make -j4
sudo make install
```

Visit [libnfc](https://github.com/nfc-tools/libnfc#installation) for details.

## Installation

```elixir
def deps do
  [
    {:libnfc_ex, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
{:ok, device} = LibNFC.open()

{:ok, target_info} =
  LibNFC.initiator_select_passive_target(device)

IO.puts("Target #{LibNFC.Utils.uid_hex(target_info["uid"])} in range")
```

<!-- MDOC -->

## Alternatives

- [`nerves_io_nfc`](https://github.com/arjan/nerves_io_nfc) has similar scope but is tied to Nerves
