from __future__ import (absolute_import, division, print_function)

__metaclass__ = type

from ansible.plugins.callback import CallbackBase
import subprocess


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'memory'
    CALLBACK_NEEDS_WHITELIST = True

    def current_mem_usage(self):
        cmd_free = subprocess.Popen(['free', '-m'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        cmd_free_out, cmd_free_error = cmd_free.communicate()
        self._display.display(cmd_free_out)

    def v2_runner_on_ok(self, result):
        self.current_mem_usage()

    def v2_runner_on_failed(self, result, ignore_errors=True):
        self.current_mem_usage()

    def v2_runner_on_unreachable(self, result):
        self.current_mem_usage()