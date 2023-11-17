# Copyright 2023 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================
r"""Produces a `compile_commands.json` from the output of `bazel aquery`.

This tool requires that a build has been completed for all targets in the
query (e.g., for the example usage below `bazel build //xla/...`). This is due
to generated files like proto headers and files generated via tablegen. So if
LSP or other tools get out of date, it may be necessary to rebuild or regenerate
`compile_commands.json`, or both.

Example usage:
  bazel aquery "mnemonic(CppCompile, //xla/...)" --output=jsonproto | \
      python3 build_tools/lint/generate_compile_commands.py
"""
import dataclasses
import json
import logging
import pathlib
import sys
from typing import Any

_JSONDict = dict[Any, Any]  # Approximates parsed JSON

_DISALLOWED_ARGS = frozenset(["-fno-canonical-system-headers"])
_XLA_SRC_ROOT = pathlib.Path(__file__).absolute().parent.parent.parent


@dataclasses.dataclass
class CompileCommand:
  """Represents a compilation command with options on a specific file."""

  file: str
  arguments: list[str]

  @classmethod
  def from_args_list(cls, args_list: list[str]) -> "CompileCommand":
    """Alternative constructor which uses the args_list from `bazel aquery`.

    This collects arguments and the file being run on from the output of
    `bazel aquery`. Also filters out arguments which break clang-tidy.

    Arguments:
      args_list: List of arguments generated by `bazel aquery`

    Returns:
      The corresponding ClangTidyCommand.
    """
    cc_file = None
    filtered_args = []

    for arg in args_list:
      if arg in _DISALLOWED_ARGS:
        continue

      if arg.endswith(".cc"):
        cc_file = arg

      filtered_args.append(arg)

    return cls(cc_file, filtered_args)

  def to_dumpable_json(self, directory: str) -> _JSONDict:
    return {
        "directory": directory,
        "file": self.file,
        "arguments": self.arguments,
    }


def extract_compile_commands(
    parsed_aquery_output: _JSONDict,
) -> list[CompileCommand]:
  """Gathers compile commands to run from `bazel aquery` JSON output.

  Arguments:
    parsed_aquery_output: Parsed JSON representing the output of `bazel aquery
      --output=jsonproto`.

  Returns:
    The list of CompileCommands that should be executed.
  """
  actions = parsed_aquery_output["actions"]

  commands = []
  for action in actions:
    command = CompileCommand.from_args_list(action["arguments"])
    commands.append(command)
  return commands


def main():
  # Setup logging
  logging.basicConfig()
  logging.getLogger().setLevel(logging.INFO)

  # Setup external symlink if necessary so headers can be found in include paths
  if not (external := _XLA_SRC_ROOT / "external").exists():
    logging.info("Symlinking `xla/bazel-xla/external` to `xla/external`")
    external.symlink_to(_XLA_SRC_ROOT / "bazel-xla" / "external")

  logging.info("Reading `bazel aquery` output from stdin...")
  parsed_aquery_output = json.loads(sys.stdin.read())

  commands = extract_compile_commands(parsed_aquery_output)

  with (_XLA_SRC_ROOT / "compile_commands.json").open("w") as f:
    json.dump(
        [
            command.to_dumpable_json(directory=str(_XLA_SRC_ROOT))
            for command in commands
        ],
        f,
    )


if __name__ == "__main__":
  main()