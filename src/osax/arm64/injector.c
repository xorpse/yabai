#include <stdlib.h>
#include <string.h>

#include "frida-core.h"

#define YABAI_PAYLOAD_PATH "/Library/ScriptingAdditions/yabai.osax/Contents/Resources/payload.bundle/Contents/MacOS/payload"

static void on_message(FridaScript *script, const gchar *message, GBytes *data, gpointer user_data);

static GMainLoop *loop = NULL;
static int return_val = 1;

const char *script_payload =
  "function loadYabaiSA(sa_path) {\n"
  "  var RTLD_NOW = 0x02;\n"
  "  var _dlopen = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);\n\n"
  "  var path = Memory.allocUtf8String(sa_path);\n"
  "  var handle = _dlopen(path, RTLD_NOW);\n"
  "  if (handle.isNull()) {\n"
  "    console.error('[e] failed to inject scripting addition payload \"" YABAI_PAYLOAD_PATH "\" into Dock');\n"
  "    send('failure');\n"
  "    return;\n"
  "  }\n"
  "  console.log('[*] injected scripting addition payload into Dock');\n"
  "  send('success');\n"
  "}\n\n"
  "var sa_path = '" YABAI_PAYLOAD_PATH "';\n"
  "loadYabaiSA(sa_path);";


int inject_yabai() {
  gint num_devices, i;
  GPid pid;
  GError *error = NULL;

  FridaDevice *device;
  FridaDeviceManager *manager;
  FridaDeviceList * devices;
  FridaDevice *local_device;
  FridaProcess *dock;
  FridaScript *script;
  FridaScriptOptions *options;
  FridaSession *session;

  frida_init();

  loop = g_main_loop_new(NULL, TRUE);
  manager = frida_device_manager_new();

  devices = frida_device_manager_enumerate_devices_sync(manager, NULL, &error);
  if (error != NULL) {
    g_printerr("[e] failed to enumerate devices: %s\n", error->message);
    g_error_free(error);
    frida_unref(devices);
    goto cleanup;
  }

  local_device = NULL;
  num_devices = frida_device_list_size(devices);
  for (i = 0; i != num_devices; i++) {
    device = frida_device_list_get(devices, i);

    if (frida_device_get_dtype(device) == FRIDA_DEVICE_TYPE_LOCAL) {
      local_device = g_object_ref(device);
      g_object_unref(device);
      break;
    }

    g_object_unref(device);
  }

  if (local_device == NULL) {
    g_printerr("[e] failed find a 'local' device\n");
    frida_unref(devices);

    return_val = 0;
    goto cleanup;
  }

  frida_unref(devices);
  devices = NULL;

  dock = frida_device_get_process_by_name_sync(
      local_device,
      "Dock",
      -1,
      NULL,
      &error
  );

  if (error != NULL) {
    g_printerr("[e] failed to get Dock process information: %s\n", error->message);
    g_error_free(error);
    frida_unref(dock);

    return_val = 0;
    goto cleanup;
  }

  pid = frida_process_get_pid(dock);
  frida_unref(dock);

  session = frida_device_attach_sync(local_device, pid, FRIDA_REALM_NATIVE, NULL, &error);

  if (error != NULL) {
    g_printerr("[e] failed to establish session: %s\n", error->message);
    g_error_free(error);
    frida_unref(session);

    return_val = 0;
    goto cleanup;
  }


  if (frida_session_is_detached(session)) {
    g_printerr("[e] session detached prematurely\n");
    frida_unref(session);

    return_val = 0;
    goto cleanup;
  }

  g_print("[*] attached to Dock (pid = %i)\n", pid);

  options = frida_script_options_new();
  frida_script_options_set_name(options, "inject-yabai-sa");
  frida_script_options_set_runtime(options, FRIDA_SCRIPT_RUNTIME_QJS);

  script = frida_session_create_script_sync(session, script_payload, options, NULL, &error);
  if (error != NULL) {
    g_print("[e] failed to create script to load into Dock: %s\n", error->message);
    g_error_free(error);

    frida_unref(script);
    frida_session_detach_sync(session, NULL, NULL);
    frida_unref(session);

    return_val = 0;
    goto cleanup;
  }

  g_clear_object(&options);
  g_signal_connect(script, "message", G_CALLBACK(on_message), NULL);

  frida_script_load_sync(script, NULL, &error);

  if (error != NULL) {
    g_print("[e] failed to load script into Dock: %s\n", error->message);
    g_error_free(error);

    frida_unref(script);
    frida_session_detach_sync(session, NULL, NULL);
    frida_unref(session);

    return_val = 0;
    goto cleanup;
  }

  if (g_main_loop_is_running(loop)) {
    g_main_loop_run(loop);
  }

  frida_script_unload_sync(script, NULL, NULL);
  frida_unref(script);

  frida_session_detach_sync(session, NULL, NULL);
  frida_unref (session);

  g_print ("[*] detached from Dock\n");

cleanup:
  frida_unref(local_device);

  frida_device_manager_close_sync(manager, NULL, NULL);
  frida_unref(manager);

  return return_val;
}

static void on_message(FridaScript *script, const gchar *message, GBytes * data, gpointer user_data) {
  JsonParser *parser;
  JsonObject *root;
  const gchar *type;

  parser = json_parser_new();
  json_parser_load_from_data(parser, message, -1, NULL);
  root = json_node_get_object(json_parser_get_root(parser));

  type = json_object_get_string_member(root, "type");
  if (strcmp(type, "log") == 0) {
    const gchar * log_message;

    log_message = json_object_get_string_member(root, "payload");
    g_print("%s\n", log_message);
  } else if (strcmp(type, "send") == 0) {
    const gchar * send_message;

    send_message = json_object_get_string_member(root, "payload");

    if (strcmp(send_message, "success") == 0 || strcmp(send_message, "failure") == 0) {
      if (strcmp(send_message, "failure") == 0) {
          return_val = 0;
      }
      g_main_loop_quit(loop);
    }
  }

  g_object_unref(parser);
}
