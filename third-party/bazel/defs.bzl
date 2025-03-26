###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run @@//third-party:vendor
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependencies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({
            tuple(_CONDITIONS[condition]): deps.values(),
            "//conditions:default": [],
        })

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": dict(common_items)}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        for triple in condition_triples:
            if triple in crate_aliases:
                crate_aliases[triple].update(deps)
            else:
                crate_aliases.update({triple: dict(deps.items() + common_items)})

    return select(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "third-party": {
        _COMMON_CONDITION: {
            "cc": Label("@vendor//:cc-1.2.17"),
            "clap": Label("@vendor//:clap-4.5.32"),
            "codespan-reporting": Label("@vendor//:codespan-reporting-0.12.0"),
            "foldhash": Label("@vendor//:foldhash-0.1.5"),
            "proc-macro2": Label("@vendor//:proc-macro2-1.0.94"),
            "quote": Label("@vendor//:quote-1.0.40"),
            "scratch": Label("@vendor//:scratch-1.0.8"),
            "syn": Label("@vendor//:syn-2.0.100"),
        },
    },
}

_NORMAL_ALIASES = {
    "third-party": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "third-party": {
    },
}

_NORMAL_DEV_ALIASES = {
    "third-party": {
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "third-party": {
        _COMMON_CONDITION: {
            "rustversion": Label("@vendor//:rustversion-1.0.20"),
        },
    },
}

_PROC_MACRO_ALIASES = {
    "third-party": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "third-party": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "third-party": {
    },
}

_BUILD_DEPENDENCIES = {
    "third-party": {
    },
}

_BUILD_ALIASES = {
    "third-party": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "third-party": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "third-party": {
    },
}

_CONDITIONS = {
    "aarch64-apple-darwin": ["@rules_rust//rust/platform:aarch64-apple-darwin"],
    "aarch64-apple-ios": ["@rules_rust//rust/platform:aarch64-apple-ios"],
    "aarch64-apple-ios-sim": ["@rules_rust//rust/platform:aarch64-apple-ios-sim"],
    "aarch64-linux-android": ["@rules_rust//rust/platform:aarch64-linux-android"],
    "aarch64-pc-windows-gnullvm": [],
    "aarch64-pc-windows-msvc": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc"],
    "aarch64-unknown-fuchsia": ["@rules_rust//rust/platform:aarch64-unknown-fuchsia"],
    "aarch64-unknown-linux-gnu": ["@rules_rust//rust/platform:aarch64-unknown-linux-gnu"],
    "aarch64-unknown-nixos-gnu": ["@rules_rust//rust/platform:aarch64-unknown-nixos-gnu"],
    "aarch64-unknown-nto-qnx710": ["@rules_rust//rust/platform:aarch64-unknown-nto-qnx710"],
    "aarch64-unknown-uefi": ["@rules_rust//rust/platform:aarch64-unknown-uefi"],
    "arm-unknown-linux-gnueabi": ["@rules_rust//rust/platform:arm-unknown-linux-gnueabi"],
    "armv7-linux-androideabi": ["@rules_rust//rust/platform:armv7-linux-androideabi"],
    "armv7-unknown-linux-gnueabi": ["@rules_rust//rust/platform:armv7-unknown-linux-gnueabi"],
    "cfg(all(any(target_arch = \"x86_64\", target_arch = \"arm64ec\"), target_env = \"msvc\", not(windows_raw_dylib)))": ["@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "cfg(all(target_arch = \"aarch64\", target_env = \"msvc\", not(windows_raw_dylib)))": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc"],
    "cfg(all(target_arch = \"x86\", target_env = \"gnu\", not(target_abi = \"llvm\"), not(windows_raw_dylib)))": ["@rules_rust//rust/platform:i686-unknown-linux-gnu"],
    "cfg(all(target_arch = \"x86\", target_env = \"msvc\", not(windows_raw_dylib)))": ["@rules_rust//rust/platform:i686-pc-windows-msvc"],
    "cfg(all(target_arch = \"x86_64\", target_env = \"gnu\", not(target_abi = \"llvm\"), not(windows_raw_dylib)))": ["@rules_rust//rust/platform:x86_64-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "cfg(any())": [],
    "cfg(windows)": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc", "@rules_rust//rust/platform:i686-pc-windows-msvc", "@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "i686-apple-darwin": ["@rules_rust//rust/platform:i686-apple-darwin"],
    "i686-linux-android": ["@rules_rust//rust/platform:i686-linux-android"],
    "i686-pc-windows-gnullvm": [],
    "i686-pc-windows-msvc": ["@rules_rust//rust/platform:i686-pc-windows-msvc"],
    "i686-unknown-freebsd": ["@rules_rust//rust/platform:i686-unknown-freebsd"],
    "i686-unknown-linux-gnu": ["@rules_rust//rust/platform:i686-unknown-linux-gnu"],
    "powerpc-unknown-linux-gnu": ["@rules_rust//rust/platform:powerpc-unknown-linux-gnu"],
    "riscv32imc-unknown-none-elf": ["@rules_rust//rust/platform:riscv32imc-unknown-none-elf"],
    "riscv64gc-unknown-none-elf": ["@rules_rust//rust/platform:riscv64gc-unknown-none-elf"],
    "s390x-unknown-linux-gnu": ["@rules_rust//rust/platform:s390x-unknown-linux-gnu"],
    "thumbv7em-none-eabi": ["@rules_rust//rust/platform:thumbv7em-none-eabi"],
    "thumbv8m.main-none-eabi": ["@rules_rust//rust/platform:thumbv8m.main-none-eabi"],
    "wasm32-unknown-unknown": ["@rules_rust//rust/platform:wasm32-unknown-unknown"],
    "wasm32-wasip1": ["@rules_rust//rust/platform:wasm32-wasip1"],
    "x86_64-apple-darwin": ["@rules_rust//rust/platform:x86_64-apple-darwin"],
    "x86_64-apple-ios": ["@rules_rust//rust/platform:x86_64-apple-ios"],
    "x86_64-linux-android": ["@rules_rust//rust/platform:x86_64-linux-android"],
    "x86_64-pc-windows-gnullvm": [],
    "x86_64-pc-windows-msvc": ["@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "x86_64-unknown-freebsd": ["@rules_rust//rust/platform:x86_64-unknown-freebsd"],
    "x86_64-unknown-fuchsia": ["@rules_rust//rust/platform:x86_64-unknown-fuchsia"],
    "x86_64-unknown-linux-gnu": ["@rules_rust//rust/platform:x86_64-unknown-linux-gnu"],
    "x86_64-unknown-nixos-gnu": ["@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "x86_64-unknown-none": ["@rules_rust//rust/platform:x86_64-unknown-none"],
    "x86_64-unknown-uefi": ["@rules_rust//rust/platform:x86_64-unknown-uefi"],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates.

    Returns:
      A list of repos visible to the module through the module extension.
    """
    maybe(
        http_archive,
        name = "vendor__anstyle-1.0.10",
        sha256 = "55cc3b69f167a1ef2e161439aa98aed94e6028e5f9a59be9a6ffb47aef1651f9",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/anstyle/1.0.10/download"],
        strip_prefix = "anstyle-1.0.10",
        build_file = Label("//third-party/bazel:BUILD.anstyle-1.0.10.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__cc-1.2.17",
        sha256 = "1fcb57c740ae1daf453ae85f16e37396f672b039e00d9d866e07ddb24e328e3a",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/cc/1.2.17/download"],
        strip_prefix = "cc-1.2.17",
        build_file = Label("//third-party/bazel:BUILD.cc-1.2.17.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__clap-4.5.32",
        sha256 = "6088f3ae8c3608d19260cd7445411865a485688711b78b5be70d78cd96136f83",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap/4.5.32/download"],
        strip_prefix = "clap-4.5.32",
        build_file = Label("//third-party/bazel:BUILD.clap-4.5.32.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__clap_builder-4.5.32",
        sha256 = "22a7ef7f676155edfb82daa97f99441f3ebf4a58d5e32f295a56259f1b6facc8",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap_builder/4.5.32/download"],
        strip_prefix = "clap_builder-4.5.32",
        build_file = Label("//third-party/bazel:BUILD.clap_builder-4.5.32.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__clap_lex-0.7.4",
        sha256 = "f46ad14479a25103f283c0f10005961cf086d8dc42205bb44c46ac563475dca6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap_lex/0.7.4/download"],
        strip_prefix = "clap_lex-0.7.4",
        build_file = Label("//third-party/bazel:BUILD.clap_lex-0.7.4.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__codespan-reporting-0.12.0",
        sha256 = "fe6d2e5af09e8c8ad56c969f2157a3d4238cebc7c55f0a517728c38f7b200f81",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/codespan-reporting/0.12.0/download"],
        strip_prefix = "codespan-reporting-0.12.0",
        build_file = Label("//third-party/bazel:BUILD.codespan-reporting-0.12.0.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__foldhash-0.1.5",
        sha256 = "d9c4f5dac5e15c24eb999c26181a6ca40b39fe946cbe4c263c7209467bc83af2",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/foldhash/0.1.5/download"],
        strip_prefix = "foldhash-0.1.5",
        build_file = Label("//third-party/bazel:BUILD.foldhash-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__proc-macro2-1.0.94",
        sha256 = "a31971752e70b8b2686d7e46ec17fb38dad4051d94024c88df49b667caea9c84",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/proc-macro2/1.0.94/download"],
        strip_prefix = "proc-macro2-1.0.94",
        build_file = Label("//third-party/bazel:BUILD.proc-macro2-1.0.94.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__quote-1.0.40",
        sha256 = "1885c039570dc00dcb4ff087a89e185fd56bae234ddc7f056a945bf36467248d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/quote/1.0.40/download"],
        strip_prefix = "quote-1.0.40",
        build_file = Label("//third-party/bazel:BUILD.quote-1.0.40.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__rustversion-1.0.20",
        sha256 = "eded382c5f5f786b989652c49544c4877d9f015cc22e145a5ea8ea66c2921cd2",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/rustversion/1.0.20/download"],
        strip_prefix = "rustversion-1.0.20",
        build_file = Label("//third-party/bazel:BUILD.rustversion-1.0.20.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__scratch-1.0.8",
        sha256 = "9f6280af86e5f559536da57a45ebc84948833b3bee313a7dd25232e09c878a52",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/scratch/1.0.8/download"],
        strip_prefix = "scratch-1.0.8",
        build_file = Label("//third-party/bazel:BUILD.scratch-1.0.8.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__serde-1.0.219",
        sha256 = "5f0e2c6ed6606019b4e29e69dbaba95b11854410e5347d525002456dbbb786b6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/serde/1.0.219/download"],
        strip_prefix = "serde-1.0.219",
        build_file = Label("//third-party/bazel:BUILD.serde-1.0.219.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__serde_derive-1.0.219",
        sha256 = "5b0276cf7f2c73365f7157c8123c21cd9a50fbbd844757af28ca1f5925fc2a00",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/serde_derive/1.0.219/download"],
        strip_prefix = "serde_derive-1.0.219",
        build_file = Label("//third-party/bazel:BUILD.serde_derive-1.0.219.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__shlex-1.3.0",
        sha256 = "0fda2ff0d084019ba4d7c6f371c95d8fd75ce3524c3cb8fb653a3023f6323e64",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/shlex/1.3.0/download"],
        strip_prefix = "shlex-1.3.0",
        build_file = Label("//third-party/bazel:BUILD.shlex-1.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__syn-2.0.100",
        sha256 = "b09a44accad81e1ba1cd74a32461ba89dee89095ba17b32f5d03683b1b1fc2a0",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/syn/2.0.100/download"],
        strip_prefix = "syn-2.0.100",
        build_file = Label("//third-party/bazel:BUILD.syn-2.0.100.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__termcolor-1.4.1",
        sha256 = "06794f8f6c5c898b3275aebefa6b8a1cb24cd2c6c79397ab15774837a0bc5755",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/termcolor/1.4.1/download"],
        strip_prefix = "termcolor-1.4.1",
        build_file = Label("//third-party/bazel:BUILD.termcolor-1.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__unicode-ident-1.0.18",
        sha256 = "5a5f39404a5da50712a4c1eecf25e90dd62b613502b7e925fd4e4d19b5c96512",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-ident/1.0.18/download"],
        strip_prefix = "unicode-ident-1.0.18",
        build_file = Label("//third-party/bazel:BUILD.unicode-ident-1.0.18.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__unicode-width-0.2.0",
        sha256 = "1fc81956842c57dac11422a97c3b8195a1ff727f06e85c84ed2e8aa277c9a0fd",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-width/0.2.0/download"],
        strip_prefix = "unicode-width-0.2.0",
        build_file = Label("//third-party/bazel:BUILD.unicode-width-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__winapi-util-0.1.9",
        sha256 = "cf221c93e13a30d793f7645a0e7762c55d169dbb0a49671918a2319d289b10bb",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-util/0.1.9/download"],
        strip_prefix = "winapi-util-0.1.9",
        build_file = Label("//third-party/bazel:BUILD.winapi-util-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows-sys-0.59.0",
        sha256 = "1e38bc4d79ed67fd075bcc251a1c39b32a1776bbe92e5bef1f0bf1f8c531853b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows-sys/0.59.0/download"],
        strip_prefix = "windows-sys-0.59.0",
        build_file = Label("//third-party/bazel:BUILD.windows-sys-0.59.0.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows-targets-0.52.6",
        sha256 = "9b724f72796e036ab90c1021d4780d4d3d648aca59e491e6b98e725b84e99973",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows-targets/0.52.6/download"],
        strip_prefix = "windows-targets-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows-targets-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_aarch64_gnullvm-0.52.6",
        sha256 = "32a4622180e7a0ec044bb555404c800bc9fd9ec262ec147edd5989ccd0c02cd3",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_aarch64_gnullvm/0.52.6/download"],
        strip_prefix = "windows_aarch64_gnullvm-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_aarch64_gnullvm-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_aarch64_msvc-0.52.6",
        sha256 = "09ec2a7bb152e2252b53fa7803150007879548bc709c039df7627cabbd05d469",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_aarch64_msvc/0.52.6/download"],
        strip_prefix = "windows_aarch64_msvc-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_aarch64_msvc-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_i686_gnu-0.52.6",
        sha256 = "8e9b5ad5ab802e97eb8e295ac6720e509ee4c243f69d781394014ebfe8bbfa0b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_i686_gnu/0.52.6/download"],
        strip_prefix = "windows_i686_gnu-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_i686_gnu-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_i686_gnullvm-0.52.6",
        sha256 = "0eee52d38c090b3caa76c563b86c3a4bd71ef1a819287c19d586d7334ae8ed66",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_i686_gnullvm/0.52.6/download"],
        strip_prefix = "windows_i686_gnullvm-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_i686_gnullvm-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_i686_msvc-0.52.6",
        sha256 = "240948bc05c5e7c6dabba28bf89d89ffce3e303022809e73deaefe4f6ec56c66",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_i686_msvc/0.52.6/download"],
        strip_prefix = "windows_i686_msvc-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_i686_msvc-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_x86_64_gnu-0.52.6",
        sha256 = "147a5c80aabfbf0c7d901cb5895d1de30ef2907eb21fbbab29ca94c5b08b1a78",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_x86_64_gnu/0.52.6/download"],
        strip_prefix = "windows_x86_64_gnu-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_x86_64_gnu-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_x86_64_gnullvm-0.52.6",
        sha256 = "24d5b23dc417412679681396f2b49f3de8c1473deb516bd34410872eff51ed0d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_x86_64_gnullvm/0.52.6/download"],
        strip_prefix = "windows_x86_64_gnullvm-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_x86_64_gnullvm-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_x86_64_msvc-0.52.6",
        sha256 = "589f6da84c646204747d1270a2a5661ea66ed1cced2631d546fdfb155959f9ec",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_x86_64_msvc/0.52.6/download"],
        strip_prefix = "windows_x86_64_msvc-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_x86_64_msvc-0.52.6.bazel"),
    )

    return [
        struct(repo = "vendor__cc-1.2.17", is_dev_dep = False),
        struct(repo = "vendor__clap-4.5.32", is_dev_dep = False),
        struct(repo = "vendor__codespan-reporting-0.12.0", is_dev_dep = False),
        struct(repo = "vendor__foldhash-0.1.5", is_dev_dep = False),
        struct(repo = "vendor__proc-macro2-1.0.94", is_dev_dep = False),
        struct(repo = "vendor__quote-1.0.40", is_dev_dep = False),
        struct(repo = "vendor__rustversion-1.0.20", is_dev_dep = False),
        struct(repo = "vendor__scratch-1.0.8", is_dev_dep = False),
        struct(repo = "vendor__syn-2.0.100", is_dev_dep = False),
    ]
