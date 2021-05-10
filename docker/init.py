#!/usr/bin/env python3
import os
import sys
import argparse
import signal
from typing import List
from lib.init_parse import InitParse


def parse_args(args) -> argparse.Namespace:
    """Parse arguments.

    param args: an argument array
    :return: The argument object.
    :rtype: object
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "-e",
        "--env-files",
        type=str,
        default="env.json",
        help="A colon-eliminated list of environment files",
    )

    return parser.parse_args(args)


def signal_handler(sig, _):
    """Handle signals.

    :param int sig: The signal of which to handle.
    :param object _: unused frame stack.
    """
    if sig == signal.SIGINT:
        print("\n## Exiting. ##\n")
        sys.exit(0)


def main(args=None):
    cwd = os.getcwd()
    signal.signal(signal.SIGINT, signal_handler)
    args = parse_args(args)
    env_files: List[str] = args.env_files.split(":")
    init = None
    for env_file in env_files:
        if not os.path.isfile(env_file):
            print("{}: No such file".format(env_file))
            sys.exit(1)
    if not env_files:
        print("No environment files defined!")
        sys.exit(1)
    for env_file in env_files:
        init = InitParse(env_file)
        if not init.run():
            sys.exit(1)
        os.chdir(cwd)
    if init:
        if init.exit:
            print("######## Exiting ########")
            sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()