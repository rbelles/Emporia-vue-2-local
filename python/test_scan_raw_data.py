# Copyright 2023 Robert Belles MIT License
# importing the modules struct and ctypes
import struct
from ctypes import *
from enum import Enum, unique
from collections import namedtuple 
import binascii


@unique
class PhaseInputWire (Enum):
    BLACK = 0
    RED = 1
    BLUE = 2


@unique
class CTInputPort (Enum):
    A = 0
    B = 1
    C = 2
    ONE = 3
    TWO = 4
    THREE = 5
    FOUR = 6
    FIVE = 7
    SIX = 8
    SEVEN = 9
    EIGHT = 10
    NINE = 11
    TEN = 12
    ELEVEN = 13
    TWELVE = 14
    THIRTEEN = 15
    FOURTEEN = 16
    FIFTEEN = 17
    SIXTEEN = 18


class PowerEntry (Structure):
    _fields_ = [("p_black", c_int32),
                ("p_red", c_int32),
                ("p_blue", c_int32)]
    _pack_ = 4


class SensorReading (Structure):
    _fields_ = [("is_unread", c_bool),
                ("checksum", c_uint8),
                ("unknown", c_uint8),
                ("sequence_num", c_uint8),
                ("power", PowerEntry * 19),
                ("voltage", c_uint16 * 3),
                ("frequency", c_uint16),
                ("degerees", c_uint16 * 2),
                ("current", c_uint16 * 19),
                ("end", c_uint16)]
    _pack_ = 4

#capture of i2c data 
my_data = ''' Paste data here '''



print (sizeof(SensorReading))
print (len(my_data))

print("==========================RAW HEX DATA AS ENTERED======================================")
print(my_data)

my_binary_data=bytearray.fromhex(my_data)

print("==========================RAW BACKED BINARY DATA=======================================")
print(my_binary_data)
print("==========================RAW UNPACKED DATA============================================")
print(struct.unpack_from('@?3B57i3HH2H19HH', my_binary_data, 0))
print("==========================Named UNPACKED DATA==========================================")
PowerData = namedtuple('PowerData', '''is_unread checksum unknown sequence_num 
                       power_0a power_0b power_0c 
                       power_1a power_1b power_1c 
                       power_2a power_2b power_2c 
                       power_3a power_3b power_3c 
                       power_4a power_4b power_4c 
                       power_5a power_5b power_5c 
                       power_6a power_6b power_6c 
                       power_7a power_7b power_7c 
                       power_8a power_8b power_8c 
                       power_9a power_9b power_9c 
                       power_10a power_10b power_10c 
                       power_11a power_11b power_11c 
                       power_12a power_12b power_12c 
                       power_13a power_13b power_13c 
                       power_14a power_14b power_14c 
                       power_15a power_15b power_15c 
                       power_16a power_16b power_16c 
                       power_17a power_17b power_17c 
                       power_18a power_18b power_18c
                       volts_a Volts_b volts_c
                       Frequency Phase_angle_a phase_angle_b
                       current_0 current_1 current_2 current_3 current_4 current_5 current_6
                       current_7 current_8 current_9 current_10 current_11 current_12 current_13
                       current_14 current_15 current_16 current_17 current_18 end''')
print(PowerData._make(struct.unpack_from('@?3B57i3HH2H19HH', my_binary_data)))
print("=============================unpacked using c struct==============================================")


my_readings = SensorReading.from_buffer_copy(my_binary_data, 0)

print('voltage Black: {:.2f}   Frequency: {:.2f}Hz  Raw Voltage: {:d} Calibration: {:0.7f}'.format(
    my_readings.voltage[PhaseInputWire.BLACK.value] * 0.0229308, 
    25310.0 / my_readings.frequency, 
    my_readings.voltage[PhaseInputWire.BLACK.value], 
    0.0229308))
print('voltage Red: {:.2f} Phase Rotation: {:.2f} Degrees  Raw Voltage: {:d} Calibration: {:0.7f}'.format(
    my_readings.voltage[PhaseInputWire.RED.value] * 0.0220000, 
    my_readings.degerees[PhaseInputWire.RED.value - 1] * 360.0 / my_readings.frequency, 
    my_readings.voltage[PhaseInputWire.RED.value], 
    0.0220000))
print('voltage Blue: {:.2f} Phase Rotation: {:.2f} Degrees  Raw Voltage: {:d} Calibration: {:0.7f}'.format(
    my_readings.voltage[PhaseInputWire.BLUE.value] * 0.0217630, 
    my_readings.degerees[PhaseInputWire.BLUE.value - 1] * 360.0 / my_readings.frequency, 
    my_readings.voltage[PhaseInputWire.BLUE.value], 
    0.0217630))


for CTPortNumber in CTInputPort:

    if CTPortNumber.value <= 3:
        scalar = 775.0 / 42624.0
        correction_factor = 5.5
    else:
        scalar = 775.0 / 170496.0
        correction_factor = 22
    calibration = 0.022

    print('Probe {:02d} Current (I): {:5.1f} Power (black): {:8.3f} (red): {:8.3f} (blue): {:8.3f}'.format(
        CTPortNumber.value, 
        (my_readings.current[CTPortNumber.value] * scalar), 
        (my_readings.power[CTPortNumber.value].p_black * calibration) / correction_factor, 
        (my_readings.power[CTPortNumber.value].p_red * calibration) / correction_factor, 
        (my_readings.power[CTPortNumber.value].p_blue * calibration) / correction_factor))
