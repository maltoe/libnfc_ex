/* SPDX-License-Identifier: Apache-2.0 */

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <erl_nif.h>
#include <nfc/nfc.h>

/* *** Device list/open/dealloc *************************************************** */

// maximum devices returned by list_devices
#define MAX_DEVICE_COUNT 16

typedef struct {
  nfc_device *device;
} DeviceResource;

ErlNifResourceType* LIBNFC_DEVICE_RESOURCE_TYPE;

static ERL_NIF_TERM libnfc_nif_list_devices(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if (argc != 0)
    return enif_make_badarg(env);

  ERL_NIF_TERM result = enif_make_list(env, 0);

  nfc_connstring connstrings[MAX_DEVICE_COUNT];
  size_t devices = nfc_list_devices(enif_priv_data(env), connstrings, MAX_DEVICE_COUNT);

  for(size_t i = 0; i < devices; ++i) {
    ERL_NIF_TERM device = enif_make_string(env, connstrings[i], ERL_NIF_UTF8);
    result = enif_make_list_cell(env, device, result);
  }

  return result;
}

static ERL_NIF_TERM libnfc_nif_open(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if (argc > 1)
    return enif_make_badarg(env);

  nfc_connstring connstring;

  if (argc == 1) {
    int bytes_written =
      enif_get_string(env, argv[0], connstring, NFC_BUFSIZE_CONNSTRING, ERL_NIF_UTF8);
    if(bytes_written <= 0)
      return enif_make_badarg(env);
  }

  DeviceResource* dres =
    enif_alloc_resource(LIBNFC_DEVICE_RESOURCE_TYPE, sizeof(DeviceResource));

  dres->device = nfc_open(enif_priv_data(env), argc == 1 ? connstring : NULL);
  if (!dres->device) {
    enif_release_resource(dres);
    return enif_make_atom(env, "error");
  }

  if (nfc_device_set_property_bool(dres->device, NP_INFINITE_SELECT, false) < 0) {
    enif_release_resource(dres);
    return enif_make_atom(env, "error");
  }

  ERL_NIF_TERM result = enif_make_resource(env, dres);
  enif_release_resource(dres);

  return enif_make_tuple2(env, enif_make_atom(env, "ok"), result);
}

static void libnfc_nif_dealloc_device(ErlNifEnv* env, void* obj)
{
  nfc_close(((DeviceResource*) obj)->device);
}

/* *** Tag detection ************************************************************** */

static ERL_NIF_TERM target_info_map_put(ErlNifEnv *env, ERL_NIF_TERM in, const char* key, const void* buf, size_t len)
{
  ERL_NIF_TERM out;
  ERL_NIF_TERM bin;

  unsigned char* binBuf = enif_make_new_binary(env, len, &bin);
  memcpy(binBuf, buf, len);

  assert(
    enif_make_map_put(
      env,
      in,
      enif_make_string(env, key, ERL_NIF_UTF8),
      bin,
      &out
    )
  );

  return out;
}

static ERL_NIF_TERM libnfc_nif_initiator_select_iso14443a(ErlNifEnv *env, DeviceResource* dres)
{
  const nfc_modulation nm = { NMT_ISO14443A, NBR_106 };

  nfc_target target;
  if (nfc_initiator_select_passive_target(dres->device, nm, NULL, 0, &target) > 0) {

    const nfc_iso14443a_info* info = (nfc_iso14443a_info*) &target.nti;
    ERL_NIF_TERM result = enif_make_new_map(env);

    result = target_info_map_put(
      env,
      result,
      "atqa",
      &(info->abtAtqa),
      sizeof(uint8_t) * 2
    );

    result = target_info_map_put(
      env,
      result,
      "sak",
      &(info->btSak),
      sizeof(uint8_t)
    );

    result = target_info_map_put(
      env,
      result,
      "uid",
      &(info->abtUid),
      info->szUidLen
    );

    result = target_info_map_put(
      env,
      result,
      "ats",
      &(info->abtAts),
      info->szAtsLen
    );

    return result;
  }

  return enif_make_atom(env, "nil");
}

static ERL_NIF_TERM libnfc_nif_initiator_select_passive_target(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  if (argc != 2 || !enif_is_ref(env, argv[0]) || !enif_is_atom(env, argv[1])) {
    fprintf(stderr, "expected arguments: ref, atom");
    return enif_make_badarg(env);
  }

  DeviceResource* dres;
  if (!enif_get_resource(env, argv[0], LIBNFC_DEVICE_RESOURCE_TYPE, (void**) &dres)) {
    fprintf(stderr, "first argument is not an open NFC device");
    return enif_make_badarg(env);
  }

  /*
   * nfc_initiator_deselect_target leaves some internal state behind libnfc in that prevents
   * the same tag being found again, until either a) the tag is lifted and placed again,
   * or b) the device is re-initialized as initiator. We dont want that so we just reinitialize,
   * which takes about the same time my PN532 test device.
   */
  nfc_initiator_init(dres->device);

  if (enif_is_identical(argv[1], enif_make_atom(env, "iso14443a"))) {
    return libnfc_nif_initiator_select_iso14443a(env, dres);
  }

  /* ... add other modulations here ... */

  fprintf(stderr, "unknown modulation");
  return enif_make_badarg(env);
}

static ERL_NIF_TERM libnfc_nif_initiator_target_is_present(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  if (argc != 1 || !enif_is_ref(env, argv[0])) {
    fprintf(stderr, "expected argument: ref");
    return enif_make_badarg(env);
  }

  DeviceResource* dres;
  if (!enif_get_resource(env, argv[0], LIBNFC_DEVICE_RESOURCE_TYPE, (void**) &dres)) {
    fprintf(stderr, "first argument is not an open NFC device");
    return enif_make_badarg(env);
  }

  int res = nfc_initiator_target_is_present(dres->device, NULL);

  return enif_make_int(env, res);
}
/* *** NIF load/unload ************************************************************ */

static int libnfc_nif_load(ErlNifEnv* env, void** priv, ERL_NIF_TERM load_info)
{
  LIBNFC_DEVICE_RESOURCE_TYPE =
    enif_open_resource_type(
      env,
      NULL,
      "LibNFCDevice",
      &libnfc_nif_dealloc_device,
      ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
      NULL
    );

  nfc_init((nfc_context**) priv);

  return 0;
}

static void libnfc_nif_unload(ErlNifEnv* env, void* priv)
{
  nfc_exit(priv);
}

static ERL_NIF_TERM libnfc_nif_version(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  return enif_make_string(env, nfc_version(), ERL_NIF_UTF8);
}

static ErlNifFunc libnfc_nif_funcs[] = {
  {"list_devices", 0, libnfc_nif_list_devices, 0},
  {"open", 0, libnfc_nif_open, 0},
  {"open", 1, libnfc_nif_open, 0},
  {"initiator_select_passive_target", 2, libnfc_nif_initiator_select_passive_target, 0},
  {"initiator_target_is_present", 1, libnfc_nif_initiator_target_is_present, 0},
  {"version", 0, libnfc_nif_version, 0},
};

ERL_NIF_INIT(Elixir.LibNFC.NIF, libnfc_nif_funcs, &libnfc_nif_load, NULL, NULL, &libnfc_nif_unload)
