function loadYabaiSA(sa_path) {
  var RTLD_NOW = 0x02;
  var _dlopen = new NativeFunction(Module.findExportByName(null, "dlopen"), 'pointer', ['pointer', 'int']);

  var path = Memory.allocUtf8String(sa_path);
  var handle = _dlopen(path, RTLD_NOW);
  if (handle.isNull()) {
    console.error("[e] failed to load scripting addition payload");
    return
  }

  // some debug to make sure things are working
  var _image_slide = new NativeFunction(Module.findExportByName(sa_path, "image_slide"), 'uint64', []);
  var _static_base_addr = new NativeFunction(Module.findExportByName(sa_path, "static_base_address"), 'uint64', []);

  console.log("[i] image_slide: ", _image_slide().toString(16));
  console.log("[i] static_base_addr: ", _static_base_addr().toString(16));
}

// path to scripting additions payload (compiled for arm64e(!))
var sa_path = "/path/to/yabai/src/osax/payload";
loadYabaiSA(sa_path);
