"""Init file parsing"""
import os
import sys
import json
import logging
import subprocess
from typing import Any, List, Dict, Tuple, Union
from lib.dirs import Dirs
from lib.files import Files
from lib.buildroot import Buildroot


class InitParse:
    """Init file parsing class."""

    @staticmethod
    def __print_step(step: str):
        """Print the step."""
        print("######## {} ########".format(step))

    @staticmethod
    def __parse_config_attr(
        config: Dict[str, Any],
        attribute: str,
        attribute_type: Union[type, Tuple[Union[type, Tuple[Any, ...]], ...]] = str,
        default_value: Union[str, bool] = None,
        fail: bool = False,
    ) -> Tuple[bool, Union[None, str, bool]]:
        """Parse a config file attribute.

        :param dict config: The config file of which to parse.
        :param str attribute: The attribute of which to check.
        :param object attribute_type: The proper attribute type of the attribute.
        :param default_value: A default value to return if the attribute doesn't exist.
        :param bool fail: Exit 1 if the attribute doesn't exist.
        :returns: True or False and a value
        :rtype: tuple
        """
        retval = False
        attribute_val = None
        if attribute in config:
            if isinstance(config[attribute], attribute_type):
                attribute_val = config[attribute]
                return True, attribute_val
            logging.error(
                "%s is supposed to be %s, got %s instead!",
                attribute,
                str(attribute_type).split("'")[1],
                str(type(config[attribute])).split("'")[1],
            )
            sys.exit(1)
        elif fail:
            print("Mandatory attribute: {} not defined!".format(attribute))
            sys.exit(1)
        if default_value or isinstance(default_value, bool):
            return True, default_value
        return retval, attribute_val

    def __parse_paths(self, config: Dict[str, Any]) -> bool:
        """Parse all paths from a given config."""
        defconfig = str(config["defconfig"])
        output_tree = self.__parse_config_attr(config, "output_tree", str, fail=True)[1]
        output_dir_base = "{}/{}".format(self.buildroot_path, output_tree)
        output_dir_name = self.__parse_config_attr(
            config,
            "output_dir_name",
            str,
            "output".format(output_dir_base),
        )[1]
        self.output_dir = "{}/{}".format(output_dir_base, output_dir_name)
        config_dir_name = self.__parse_config_attr(
            config, "config_dir_name", str, default_value="configs"
        )[1]
        self.config_dir_path = "{}/{}/{}".format(
            self.buildroot_path, self.config_dir_tree, config_dir_name
        )
        self.defconfig = defconfig.replace("_defconfig", "") + "_defconfig"
        self.defconfig_path = "{}/{}".format(self.config_dir_path, self.defconfig)

        if self.__parse_config_attr(config, "name", str)[0]:
            self.build_path = "{}/{}".format(self.output_dir, config["name"])
        else:
            self.build_path = "{}/{}".format(
                self.output_dir, self.defconfig.replace("_defconfig", "")
            )

        if not os.path.isfile(self.defconfig_path):
            logging.error("%s: no such file!", format(self.defconfig_path))
            sys.exit(1)

        self.dl_dir = Buildroot.parse_defconfig(
            "BR2_DL_DIR", self.defconfig_path, self.buildroot_path
        )
        if not self.dl_dir:
            self.dl_dir = "{}/{}/dl".format(
                self.buildroot_path, self.external_trees.split(":")[0]
            )
        if not Dirs.exists(self.dl_dir, make=True, fail=True):
            return False
        return True

    def __parse_fragments(self, config: Dict[str, Any]) -> None:
        """Parse all fragments if available."""
        ndx = 0
        fragments_temp: List[str] = []
        self.fragments.clear()
        for external_tree in self.external_trees.split(":"):
            extern_tree_base = "{}/{}".format(self.buildroot_path, external_tree)
            extern_tree = config["external_trees"][ndx]
            ndx += 1
            if self.__parse_config_attr(extern_tree, "fragments", list)[0]:
                fragments = list(extern_tree["fragments"])
                retval = self.__parse_config_attr(extern_tree, "fragment_dir", str)
                if retval[0]:
                    self.fragment_dir = "{}/{}".format(extern_tree_base, retval[1])
                else:
                    self.fragment_dir = "{}/configs".format(self.config_dir_path)
                for fragment in fragments:
                    fragment_path = "{}/{}".format(self.fragment_dir, fragment)
                    Files.exists(fragment_path, fail=True)
                    fragments_temp.append(fragment_path)
        self.fragments = fragments_temp

    def __parse_external_trees(self, config: Dict[str, Any]) -> str:
        external_tree_string: str = ""
        external_tree: Dict[str, Any]
        self.external_trees = ""
        self.__parse_config_attr(config, "external_trees", list, fail=True)
        external_trees: List[str] = config["external_trees"]

        for external_tree in external_trees:
            external_tree_string += (
                self.__parse_config_attr(external_tree, "name")[1] + ":"
            )
        return external_tree_string[:-1]

    def _parse_config_settings(self, config: Dict[str, Union[str, bool]]) -> bool:
        self.make = "make"
        self.__parse_config_attr(config, "defconfig", str, fail=True)
        self.build = self.__parse_config_attr(config, "build", bool, True)[1]
        self.skip = self.__parse_config_attr(config, "skip", bool, False)[1]
        self.clean = self.__parse_config_attr(config, "clean", bool, False)[1]
        self.remove = self.__parse_config_attr(config, "remove", bool, False)[1]
        if not self.__parse_config_attr(config, "verbose", bool, False)[1]:
            self.make = "brmake"
        self.external_trees = self.__parse_external_trees(config)
        self.config_dir_tree = self.__parse_config_attr(
            config, "config_dir_tree", str, fail=True
        )[1]
        if not self.__parse_paths(config):
            return False
        self.__parse_fragments(config)
        return True

    def __apply_fragments(self) -> None:
        """Apply the config fragments defined in env.json for a given config.

        Note: We run "make olddefconfig" to force the kconfig system to rebuild the .config
              with the default dependencies selected for the added fragments.
        """
        for fragment in self.fragments:
            self.__print_step("Applying fragment: {}".format(fragment))
            fragment_buff = Files.to_buffer(file_location=fragment)
            Files.save_buffer(
                "{}/.config".format(self.build_path),
                fragment_buff,
                append=True,
            )
        os.chdir(self.build_path)
        with open(os.devnull, "wb") as null:
            subprocess.check_call(
                [self.make, "olddefconfig"],
                stdout=null,
                stderr=subprocess.STDOUT,
            )
        os.chdir(self.buildroot_path)

    def apply_config(self, config: Dict[str, Union[str, bool]]) -> bool:
        """Apply all configs defined in env.json."""
        self.fragments.clear()
        if not self._parse_config_settings(config):
            return False
        Dirs.exists(self.buildroot_path, fail=True)
        Dirs.exists(self.output_dir, make=True, fail=True)

        if not Dirs.exists(self.build_path):
            cmd = "BR2_EXTERNAL={}/{} BR2_DEFCONFIG={} {} {} O={}".format(
                self.buildroot_path,
                self.external_trees,
                self.defconfig_path,
                self.make,
                self.defconfig,
                self.build_path,
            )
            os.chdir(self.buildroot_path)
            self.__print_step("Applying {}".format(self.defconfig_path))
            retval = os.system(cmd)
            if retval != 0:
                print("ERROR: Failed to apply {}".format(self.defconfig_path))
                return False
            if self.fragments:
                self.__apply_fragments()
        return True

    def clean_config(self, config: Dict[str, Union[str, bool]]) -> bool:
        """Clean all configs that have the clean boolean set to true."""
        self._parse_config_settings(config)
        if self.remove:
            if Dirs.exists(self.build_path):
                self.__print_step("Removing directory {}".format(self.build_path))
                return Dirs.remove(self.build_path)
        elif self.clean:
            if Dirs.exists(self.build_path):
                os.chdir(self.build_path)
                cmd = "{} clean".format(self.make)
                self.__print_step("Cleaning {}".format(self.defconfig))
                retval = os.system(cmd)
                if retval != 0:
                    print("ERROR: Failed to clean {}".format(self.defconfig_path))
                    return False
                os.chdir(self.buildroot_path)
                return True
        return True

    def update_buildroot(self) -> Union[bool, int]:
        """Update buildroot if set to true."""
        if self.update:
            return Buildroot.update(self.buildroot_path)
        return True

    def _parse_env(self):
        if "environment" in self.env:
            environment = self.env["environment"][0]
        else:
            environment = {}
        self.exit = self.__parse_config_attr(
            environment, "exit_after_build", bool, True
        )[1]
        self.update = self.__parse_config_attr(
            environment, "update_buildroot", bool, False
        )[1]
        self.user = self.__parse_config_attr(environment, "user", str, "br-user")[1]
        self.buildroot_path = self.__parse_config_attr(
            environment,
            "buildroot_dir_name",
            str,
            "/home/{}/buildroot".format(self.user),
        )[1]

    def build_config(self, config: Dict[str, Union[str, bool]]) -> bool:
        """Build all configs that have the build attribute set to true in env.json"""
        self._parse_config_settings(config)
        if self.build:
            os.chdir(self.build_path)
            self.__print_step("Building {}".format(self.defconfig))
            cmd = "{} BR2_DL_DIR={}".format(self.make, self.dl_dir)
            retval = os.system(cmd)
            if retval != 0:
                print("ERROR: Failed to build {}".format(self.defconfig_path))
                return False
        else:
            self.__print_step("{}: Skip build step".format(self.defconfig))
        return True

    def run(self) -> bool:
        """Run all the steps."""
        self._parse_env()
        self.update_buildroot()
        self.buildroot_path: str = "/home/{}/buildroot".format(self.user)
        for config in self.env["configs"]:
            self._parse_config_settings(config)
            if self.skip:
                self.__print_step("Skipping {}".format(self.defconfig))
                continue
            if not self.clean_config(config):
                return False
            if not self.apply_config(config):
                print("#")
                return False
        for config in self.env["configs"]:
            skip = self.__parse_config_attr(config, "skip", bool, False)[1]
            if not skip:
                if not self.build_config(config):
                    return False
        return True

    def __init__(self, env_file: str):
        with open(env_file) as env_fd:
            try:
                self.env = json.load(env_fd)
            except json.decoder.JSONDecodeError as err:
                logging.error(str(err))
                exit(1)
        self.build: bool = False
        self.build_path: str = ""
        self.buildroot_path: str = "/home/br-user/buildroot"
        self.clean: bool = False
        self.config_dir_path: str = "configs"
        self.config_dir_tree: str = ""
        self.defconfig: str = ""
        self.defconfig_path: str = ""
        self.dl_dir: str = ""
        self.exit: bool = False
        self.external_trees: str = ""
        self.fragment_dir: str = ""
        self.fragments: List[str] = []
        self.make: str = "make"
        self.output_name: str = ""
        self.output_dir: str = ""
        self.remove: bool = False
        self.skip: bool = False
        self.update: bool = False
        self.user: str = "br-user"
        self.verbose: bool = False
