"""XMOS XVF-3000 DSP parameter access for the ReSpeaker Mic Array v2.0.

Translated from the upstream `usb_4_mic_array/tuning.py` (Apache 2.0,
github.com/respeaker/usb_4_mic_array) to a minimal, self-contained form.
"""

import struct

import usb.core
import usb.util


# id, offset, type, max, min, access
PARAMETERS = {
    "AECFREEZEONOFF": (18, 7, "int", 1, 0, "rw"),
    "AECNORM": (18, 19, "float", 16, 0.25, "rw"),
    "AECPATHCHANGE": (18, 25, "int", 1, 0, "ro"),
    "RT60": (18, 26, "float", 0.9, 0.25, "ro"),
    "HPFONOFF": (18, 27, "int", 3, 0, "rw"),
    "RT60ONOFF": (18, 28, "int", 1, 0, "rw"),
    "AECSILENCELEVEL": (18, 30, "float", 1, 1e-09, "rw"),
    "AECSILENCEMODE": (18, 31, "int", 1, 0, "ro"),
    "AGCONOFF": (19, 0, "int", 1, 0, "rw"),
    "AGCMAXGAIN": (19, 1, "float", 1000, 1, "rw"),
    "AGCDESIREDLEVEL": (19, 2, "float", 0.99, 1e-08, "rw"),
    "AGCGAIN": (19, 3, "float", 1000, 1, "rw"),
    "AGCTIME": (19, 4, "float", 1, 0.1, "rw"),
    "CNIONOFF": (19, 5, "int", 1, 0, "rw"),
    "FREEZEONOFF": (19, 6, "int", 1, 0, "rw"),
    "STATNOISEONOFF": (19, 8, "int", 1, 0, "rw"),
    "GAMMA_NS": (19, 9, "float", 3, 0, "rw"),
    "MIN_NS": (19, 10, "float", 1, 0, "rw"),
    "NONSTATNOISEONOFF": (19, 11, "int", 1, 0, "rw"),
    "GAMMA_NN": (19, 12, "float", 3, 0, "rw"),
    "MIN_NN": (19, 13, "float", 1, 0, "rw"),
    "ECHOONOFF": (19, 14, "int", 1, 0, "rw"),
    "GAMMA_E": (19, 15, "float", 3, 0, "rw"),
    "GAMMA_ETAIL": (19, 16, "float", 3, 0, "rw"),
    "GAMMA_ENL": (19, 17, "float", 5, 0, "rw"),
    "NLATTENONOFF": (19, 18, "int", 1, 0, "rw"),
    "NLAEC_MODE": (19, 20, "int", 2, 0, "rw"),
    "SPEECHDETECTED": (19, 22, "int", 1, 0, "ro"),
    "FSBUPDATED": (19, 23, "int", 1, 0, "ro"),
    "FSBPATHCHANGE": (19, 24, "int", 1, 0, "ro"),
    "TRANSIENTONOFF": (19, 29, "int", 1, 0, "rw"),
    "VOICEACTIVITY": (19, 32, "int", 1, 0, "ro"),
    "STATNOISEONOFF_SR": (19, 33, "int", 1, 0, "rw"),
    "NONSTATNOISEONOFF_SR": (19, 34, "int", 1, 0, "rw"),
    "GAMMA_NS_SR": (19, 35, "float", 3, 0, "rw"),
    "GAMMA_NN_SR": (19, 36, "float", 3, 0, "rw"),
    "MIN_NS_SR": (19, 37, "float", 1, 0, "rw"),
    "MIN_NN_SR": (19, 38, "float", 1, 0, "rw"),
    "GAMMAVAD_SR": (19, 39, "float", 1000, 0, "rw"),
    "DOAANGLE": (21, 0, "int", 359, 0, "ro"),
}


TIMEOUT = 100000


class Tuning:
    def __init__(self, dev):
        self.dev = dev

    def write(self, name, value):
        try:
            param = PARAMETERS[name]
        except KeyError:
            raise ValueError(f"unknown parameter {name!r}") from None

        if param[5] == "ro":
            raise ValueError(f"{name} is read-only")

        param_id, offset, type_, max_, min_, _ = param
        if type_ == "int":
            value = int(value)
            payload = struct.pack(b"iii", offset, value, 1)
        else:
            value = float(value)
            payload = struct.pack(b"ifi", offset, value, 0)

        self.dev.ctrl_transfer(
            usb.util.CTRL_OUT
            | usb.util.CTRL_TYPE_VENDOR
            | usb.util.CTRL_RECIPIENT_DEVICE,
            0,
            0,
            param_id,
            payload,
            TIMEOUT,
        )

    def read(self, name):
        try:
            param = PARAMETERS[name]
        except KeyError:
            raise ValueError(f"unknown parameter {name!r}") from None

        param_id, offset, type_, *_ = param
        cmd = 0x80 | offset
        if type_ == "int":
            cmd |= 0x40

        response = self.dev.ctrl_transfer(
            usb.util.CTRL_IN
            | usb.util.CTRL_TYPE_VENDOR
            | usb.util.CTRL_RECIPIENT_DEVICE,
            0,
            cmd,
            param_id,
            8,
            TIMEOUT,
        )
        a, b = struct.unpack(b"ii", bytes(response))
        if type_ == "int":
            return a
        return a * (2.0 ** b)

    def close(self):
        usb.util.dispose_resources(self.dev)


def find(vid=0x2886, pid=0x0018):
    dev = usb.core.find(idVendor=vid, idProduct=pid)
    if dev is None:
        return None
    return Tuning(dev)
