load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_python//python:defs.bzl", "py_library")
load("@rules_cc//cc:defs.bzl", "cc_library", "cc_proto_library")
load("@com_github_grpc_grpc//bazel:cc_grpc_library.bzl", "cc_grpc_library")
load(
    "@com_github_grpc_grpc//bazel:python_rules.bzl",
    "py_grpc_library",
    "py_proto_library",
)

load(
    "@xla//xla/tsl:tsl.bzl",
    "clean_dep",
    "if_not_windows",
    "if_tsl_link_protobuf",
)
load("//tsl/platform:build_config_root.bzl", "if_static")

def tf_proto_library(
        name,
        srcs = None,
        protodeps = None,
        with_grpc = False,
        create_grpc_library = False,
        with_cc = True,
        cc_deps = None,
        cc_auto_deps = True,
        with_py = True,
        py_deps = None,
        py_auto_deps = True,
        **kwargs):
    proto_targets(
        name = name,
        srcs = srcs,
        deps = protodeps,
        with_grpc = create_grpc_library,
        with_cc = with_cc,
        cc_deps = cc_deps,
        cc_auto_deps = cc_auto_deps,
        with_py = with_py,
        py_deps = py_deps,
        py_auto_deps = py_auto_deps,
        **kwargs)

def tf_proto_library_cc(
        name,
        srcs = None,
        protodeps = None,
        with_grpc = False,
        create_grpc_library = False,
        with_cc = True,
        cc_deps = None,
        cc_auto_deps = True,
        with_py = False,
        py_deps = None,
        py_auto_deps = True,
        **kwargs):
    proto_targets(
        name = name,
        srcs = srcs,
        deps = protodeps,
        with_grpc = create_grpc_library,
        with_cc = with_cc,
        cc_deps = cc_deps,
        cc_auto_deps = cc_auto_deps,
        with_py = with_py,
        py_deps = py_deps,
        py_auto_deps = py_auto_deps,
        **kwargs)

def tf_proto_library_py(
        name,
        srcs = None,
        protodeps = None,
        with_grpc = False,
        create_grpc_library = False,
        with_cc = False,
        cc_deps = None,
        cc_auto_deps = True,
        with_py = True,
        py_deps = None,
        py_auto_deps = True,
        **kwargs):
    proto_targets(
        name = name,
        srcs = srcs,
        deps = protodeps,
        with_grpc = create_grpc_library,
        with_cc = with_cc,
        cc_deps = cc_deps,
        cc_auto_deps = cc_auto_deps,
        with_py = with_py,
        py_deps = py_deps,
        py_auto_deps = py_auto_deps,
        **kwargs)


def proto_targets(
        name,
        srcs = None,
        deps = None,
        with_grpc = False,
        with_cc = True,
        cc_deps = None,
        cc_auto_deps = True,
        with_py = True,
        py_deps = None,
        py_auto_deps = True,
        **kwargs):
    """Generates the following rules according to with_* parameters:
      - <name>: proto_library
      - <name>_cc: cc_library
      - <name>_py: py_library
    """

    # TODO(shengye): Support common parameters for all rules.
    # TODO(shengye): Add Python grpcio support.

    deps = deps or []
    py_deps = py_deps or []
    cc_deps = cc_deps or []

    # First, generate the proto_library target.
    proto_library_kwargs = {
        k: v
        for k, v in kwargs.items()
        if k in [
            "data",
            "compatible_with",
            "deprecation",
            "distribs",
            "exec_compatible_with",
            "exec_properties",
            "exports",
            "features",
            "import_prefix",
            "licenses",
            "restricted_to",
            "strip_import_prefix",
            "tags",
            "testonly",
            "visibility",
        ]
    }
    proto_library(
        name = name,
        srcs = srcs,
        deps = deps + well_known_proto_libs(),
        **proto_library_kwargs
    )

    # Generate for C++.
    if with_cc:
        cc_proto_library(
            name = "{}_cc_impl".format(name),
            deps = [":{}".format(name)],
            visibility = ["//visibility:public"],
        )
        cc_deps.append("{}_cc_impl".format(name))
        cc_deps.append("@com_google_protobuf//:protobuf")

        if with_grpc:
            cc_grpc_library(
                name = "{}_grpc_cc".format(name),
                srcs = [":{}".format(name)],
                deps = [":{}_cc_impl".format(name)],
                grpc_only = True,
            )
            cc_deps.append("{}_grpc_cc".format(name))
        cc_deps.append("@com_github_grpc_grpc//:grpc++")

        if cc_auto_deps:
            for dep in deps:
                dep_cc_name = "{}_cc".format(dep)
                if dep.startswith("//") and ":" not in dep:
                    dep_cc_name = "{}:{}_cc".format(dep, dep.split("/")[-1])
                cc_deps.append(dep_cc_name)

        cc_library(
            name = "{}_cc".format(name),
            deps = cc_deps,
        )

    # Generate for Python.
    if with_py:
        py_proto_library(
            name = "{}_pb_py".format(name),
            deps = [":{}".format(name)],
        )
        py_srcs = [":{}_pb_py".format(name)]
        py_deps.append(":{}_pb_py".format(name))

        if with_grpc:
            py_grpc_library(
                name = "{}_grpc_py".format(name),
                srcs = [":{}".format(name)],
                deps = [":{}_pb_py".format(name)],
            )
            py_srcs.append(":{}_grpc_py".format(name))
            py_deps.append(":{}_grpc_py".format(name))

        if py_auto_deps:
            for dep in deps:
                dep_py_name = "{}_py".format(dep)
                if dep.startswith("//") and ":" not in dep:
                    dep_py_name = "{}:{}_py".format(dep, dep.split("/")[-1])
                py_deps.append(dep_py_name)

        py_library(
            name = "{}_py".format(name),
            srcs = py_srcs,
            deps = py_deps,
        )



def well_known_proto_libs():
    """Set of standard protobuf protos, like Any and Timestamp.

    This list should be provided by protobuf.bzl, but it's not.
    """
    return [
        "@com_google_protobuf//:any_proto",
        "@com_google_protobuf//:api_proto",
        "@com_google_protobuf//:compiler_plugin_proto",
        "@com_google_protobuf//:descriptor_proto",
        "@com_google_protobuf//:duration_proto",
        "@com_google_protobuf//:empty_proto",
        "@com_google_protobuf//:field_mask_proto",
        "@com_google_protobuf//:source_context_proto",
        "@com_google_protobuf//:struct_proto",
        "@com_google_protobuf//:timestamp_proto",
        "@com_google_protobuf//:type_proto",
        "@com_google_protobuf//:wrappers_proto",
    ]

# Appends a suffix to a list of deps.
def tf_deps(deps, suffix):
    tf_deps = []

    # If the package name is in shorthand form (ie: does not contain a ':'),
    # expand it to the full name.
    for dep in deps:
        tf_dep = dep

        if not ":" in dep:
            dep_pieces = dep.split("/")
            tf_dep += ":" + dep_pieces[len(dep_pieces) - 1]

        tf_deps += [tf_dep + suffix]

    return tf_deps

# Modified from @cython//:Tools/rules.bzl
def pyx_library(
        name,
        cc_deps = [],
        py_deps = [],
        srcs = [],
        testonly = None,
        srcs_version = "PY3",
        copts = [],
        **kwargs):
    """Compiles a group of .pyx / .pxd / .py files.

    First runs Cython to create .cpp files for each input .pyx or .py + .pxd
    pair. Then builds a shared object for each, passing "cc_deps" to each cc_binary
    rule (includes Python headers by default). Finally, creates a py_library rule
    with the shared objects and any pure Python "srcs", with py_deps as its
    dependencies; the shared objects can be imported like normal Python files.

    Args:
      name: Name for the rule.
      cc_deps: C/C++ dependencies of the Cython (e.g. Numpy headers).
      py_deps: Pure Python dependencies of the final library.
      srcs: .py, .pyx, or .pxd files to either compile or pass through.
      testonly: If True, the target can only be used with tests.
      srcs_version: Version of python source files.
      copts: List of copts to pass to cc rules.
      **kwargs: Extra keyword arguments passed to the py_library.
    """

    # First filter out files that should be run compiled vs. passed through.
    py_srcs = []
    pyx_srcs = []
    pxd_srcs = []
    for src in srcs:
        if src.endswith(".pyx") or (src.endswith(".py") and
                                    src[:-3] + ".pxd" in srcs):
            pyx_srcs.append(src)
        elif src.endswith(".py"):
            py_srcs.append(src)
        else:
            pxd_srcs.append(src)
        if src.endswith("__init__.py"):
            pxd_srcs.append(src)

    # Invoke cython to produce the shared object libraries.
    for filename in pyx_srcs:
        native.genrule(
            name = filename + "_cython_translation",
            srcs = [filename],
            outs = [filename.split(".")[0] + ".cpp"],
            # Optionally use PYTHON_BIN_PATH on Linux platforms so that python 3
            # works. Windows has issues with cython_binary so skip PYTHON_BIN_PATH.
            cmd = "PYTHONHASHSEED=0 $(location @cython//:cython_binary) --cplus $(SRCS) --output-file $(OUTS)",
            testonly = testonly,
            tools = ["@cython//:cython_binary"] + pxd_srcs,
        )

    shared_objects = []
    for src in pyx_srcs:
        stem = src.split(".")[0]
        shared_object_name = stem + ".so"
        native.cc_binary(
            name = shared_object_name,
            srcs = [stem + ".cpp"],
            deps = cc_deps + ["@tsl//third_party/python_runtime:headers"],
            linkshared = 1,
            testonly = testonly,
            copts = copts,
        )
        shared_objects.append(shared_object_name)

    # Now create a py_library with these shared objects as data.
    native.py_library(
        name = name,
        srcs = py_srcs,
        deps = py_deps,
        srcs_version = srcs_version,
        data = shared_objects,
        testonly = testonly,
        **kwargs
    )


def tf_jspb_proto_library(**kwargs):
    pass


def tf_additional_lib_hdrs():
    return [
        clean_dep("//tsl/platform/default:casts.h"),
        clean_dep("//tsl/platform/default:context.h"),
        clean_dep("//tsl/platform/default:criticality.h"),
        clean_dep("//tsl/platform/default:integral_types.h"),
        clean_dep("//tsl/platform/default:logging.h"),
        clean_dep("//tsl/platform/default:mutex.h"),
        clean_dep("//tsl/platform/default:mutex_data.h"),
        clean_dep("//tsl/platform/default:stacktrace.h"),
        clean_dep("//tsl/platform/default:status.h"),
        clean_dep("//tsl/platform/default:statusor.h"),
        clean_dep("//tsl/platform/default:tracing_impl.h"),
        clean_dep("//tsl/platform/default:unbounded_work_queue.h"),
    ] + select({
        clean_dep("@xla//xla/tsl:windows"): [
            clean_dep("//tsl/platform/windows:intrinsics_port.h"),
            clean_dep("//tsl/platform/windows:stacktrace.h"),
            clean_dep("//tsl/platform/windows:subprocess.h"),
            clean_dep("//tsl/platform/windows:wide_char.h"),
            clean_dep("//tsl/platform/windows:windows_file_system.h"),
        ],
        "//conditions:default": [
            clean_dep("//tsl/platform/default:posix_file_system.h"),
            clean_dep("//tsl/platform/default:subprocess.h"),
        ],
    })

def tf_additional_all_protos():
    return ["//tensorflow/core:protos_all"]

def tf_protos_profiler_service():
    return [
        clean_dep("//tsl/profiler/protobuf:profiler_analysis_proto_cc_impl"),
        clean_dep("//tsl/profiler/protobuf:profiler_service_proto_cc_impl"),
        clean_dep("//tsl/profiler/protobuf:profiler_service_monitor_result_proto_cc_impl"),
    ]

# TODO(jakeharmon): Move TSL macros that reference TF targets back into TF
def tf_protos_grappler_impl():
    return ["//tensorflow/core/grappler/costs:op_performance_data_cc_impl"]

def tf_protos_grappler():
    return if_static(
        extra_deps = tf_protos_grappler_impl(),
        otherwise = ["//tensorflow/core/grappler/costs:op_performance_data_cc"],
    )

def tf_additional_device_tracer_srcs():
    return [
        "device_tracer_cuda.cc",
        "device_tracer_rocm.cc",
    ]

def tf_additional_test_deps():
    return []

def tf_additional_lib_deps():
    """Additional dependencies needed to build TF libraries."""
    return [
        "@com_google_absl//absl/base:base",
        "@com_google_absl//absl/container:inlined_vector",
        "@com_google_absl//absl/types:span",
    ] + if_static(
        [clean_dep("@nsync//:nsync_cpp")],
        [clean_dep("@nsync//:nsync_headers")],
    )

def tf_additional_core_deps():
    return select({
        clean_dep("@xla//xla/tsl:android"): [],
        clean_dep("@xla//xla/tsl:ios"): [],
        clean_dep("@xla//xla/tsl:linux_s390x"): [],
        "//conditions:default": [
            clean_dep("//tsl/platform/cloud:gcs_file_system"),
        ],
    })

def tf_lib_proto_parsing_deps():
    return [
        ":protos_all_cc",
        clean_dep("@eigen_archive//:eigen3"),
        clean_dep("//tsl/protobuf:protos_all_cc"),
    ]

def tf_py_clif_cc(name, visibility = None, **kwargs):
    pass

def tf_pyclif_proto_library(
        name,
        proto_lib,
        proto_srcfile = "",
        visibility = None,
        **kwargs):
    native.filegroup(name = name)
    native.filegroup(name = name + "_pb2")

def tf_additional_rpc_deps():
    return []

def tf_additional_tensor_coding_deps():
    return []

def tf_fingerprint_deps():
    return [
        "@farmhash_archive//:farmhash",
    ]

def tf_protobuf_deps():
    return if_static(
        [
            clean_dep("@com_google_protobuf//:protobuf"),
        ],
        otherwise = [clean_dep("@com_google_protobuf//:protobuf_headers")],
    )

# Link protobuf, unless the tsl_link_protobuf build flag is explicitly set to false.
def tsl_protobuf_deps():
    return ["@com_google_protobuf//:protobuf"]
    # return if_tsl_link_protobuf([clean_dep("@com_google_protobuf//:protobuf")], [clean_dep("@com_google_protobuf//:protobuf_headers")])

# When tsl_protobuf_header_only is true, we need to add the protobuf library
# back into our binaries explicitly.
def tsl_cc_test(
        name,
        deps = [],
        **kwargs):
    native.cc_test(
        name = name,
        deps = deps + if_tsl_link_protobuf(
            [],
            [
                clean_dep("@com_google_protobuf//:protobuf"),
                # TODO(ddunleavy) remove these and add proto deps to tests
                # granularly
                clean_dep("//tsl/protobuf:error_codes_proto_impl_cc_impl"),
                clean_dep("//tsl/protobuf:histogram_proto_cc_impl"),
                clean_dep("//tsl/protobuf:status_proto_cc_impl"),
                clean_dep("//tsl/profiler/protobuf:xplane_proto_cc_impl"),
                clean_dep("//tsl/profiler/protobuf:profiler_options_proto_cc_impl"),
            ],
        ),
        **kwargs
    )

def tf_portable_proto_lib():
    return ["//tensorflow/core:protos_all_cc_impl", clean_dep("//tsl/protobuf:protos_all_cc_impl")]

def tf_protobuf_compiler_deps():
    return if_static(
        [
            clean_dep("@com_google_protobuf//:protobuf"),
        ],
        otherwise = [clean_dep("@com_google_protobuf//:protobuf_headers")],
    )

def tf_windows_aware_platform_deps(name):
    return select({
        clean_dep("@xla//xla/tsl:windows"): [
            clean_dep("//tsl/platform/windows:" + name),
        ],
        "//conditions:default": [
            clean_dep("//tsl/platform/default:" + name),
        ],
    })

def tf_platform_deps(name, platform_dir = "@tsl//tsl/platform/"):
    return [platform_dir + "default:" + name]

def tf_stream_executor_deps(name, platform_dir = "@tsl//tsl/platform/"):
    return tf_platform_deps(name, platform_dir)

def tf_platform_alias(name, platform_dir = "@tsl//tsl/platform/"):
    return [platform_dir + "default:" + name]

def tf_logging_deps():
    return [clean_dep("//tsl/platform/default:logging")]

def tf_error_logging_deps():
    return [clean_dep("//tsl/platform/default:error_logging")]

def tsl_grpc_credentials_deps():
    return [clean_dep("//tsl/platform/default:grpc_credentials")]

def tf_resource_deps():
    return [clean_dep("//tsl/platform/default:resource")]

def tf_portable_deps_no_runtime():
    return [
        "@eigen_archive//:eigen3",
        "@double_conversion//:double-conversion",
        "@nsync//:nsync_cpp",
        "@com_googlesource_code_re2//:re2",
        "@farmhash_archive//:farmhash",
    ]

def tf_google_mobile_srcs_no_runtime():
    return []

def tf_google_mobile_srcs_only_runtime():
    return []

def tf_cuda_libdevice_path_deps():
    return tf_platform_deps("cuda_libdevice_path")
