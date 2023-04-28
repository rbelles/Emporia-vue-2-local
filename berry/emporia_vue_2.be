
#-  Copyright 2023 Robert Belles MIT license -#

class EMPORIA : Driver
    import json
    var wire          #- if wire == nil then the module is not initialized -#
    var raw_data
    var parsed_data
    var P_correction
    var ct_correction_factor_mains, ct_correction_factor_probe 
    var I_correction_mains, I_correction_probe
    var V_black_correction, V_blue_correction, V_red_correction
    var freq_correction
 
    

    def init()
        self.wire = tasmota.wire_scan(0x64,80)
        if self.wire
            var v = self.wire.read(0x64,0x02,1)
            if v != 0x52 return end  #- wrong device -#
            self.register_commands()
            self.raw_data = bytes()
            self.parsed_data = map()
            self.P_correction = 0.022 #- Power Calibration -#
            self.ct_correction_factor_mains = 5.5  #- CT A, B, & C -#
            self.ct_correction_factor_probe = 22  #- CT 1 - 16 -#
            self.I_correction_mains = 775.0 / 42624.0 #- Current correction CT A, B, & C -#
            self.I_correction_probe = 775.0 / 170496.0  #- Current correction CT 1 - 16 -#
            self.V_black_correction = 0.0229308
            self.V_blue_correction = 0.0220000
            self.V_red_correction = 0.0217630
            self.freq_correction = 25310.0

            print("I2C: EMPORIA VUE detected on bus "+str(self.wire.bus))
            tasmota.add_driver(self)
        end
    end
    
    def register_commands()
        tasmota.add_cmd('UnloadEmporia',
            def ()
                tasmota.remove_driver(self)
                tasmota.remove_cmd('UnloadEmporia')
                tasmota.resp_cmnd_done()
            end )

    end


    def read_emporia()
        if !self.wire return nil end  #- exit if not initialized -#
        self.raw_data.clear()
        var i = 0
        while i < 3
            self.raw_data .. self.wire.read_bytes(0x64, 0x00 + (i * 96), 96)
            i += 1
        end
        return self.raw_data
    end

    def calculate_values()
        if !self.wire return nil end  #- exit if not initialized -#
        var probe = 0
        self.parsed_data.insert('is_unread', self.raw_data.get(0x00,1))
        self.parsed_data.insert('checksum', self.raw_data.get(0x01,1))
        self.parsed_data.insert('unknown', self.raw_data.get(0x02,1))
        self.parsed_data.insert('sequence', self.raw_data.get(0x03,1))

        while probe < 19
            if probe <= 3
                self.parsed_data.insert('P' + str(probe) + '_black', self.raw_data.geti((probe * 0x0c) + 0x04,4) * self.P_correction / self.ct_correction_factor_mains)  #- probe * 0x0c + 0x04   -#
                self.parsed_data.insert('P' + str(probe) + '_red', self.raw_data.geti((probe * 0x0c) + 0x08,4) * self.P_correction / self.ct_correction_factor_mains)    #- probe * 0x0c + 0x08   -#
                self.parsed_data.insert('P' + str(probe) + '_blue', self.raw_data.geti((probe * 0x0c) + 0x0c,4) * self.P_correction / self.ct_correction_factor_mains)   #- probe * 0x0c + 0x0c   -#
            else
                self.parsed_data.insert('P' + str(probe) + '_black', self.raw_data.geti((probe * 0x0c) + 0x04,4) * self.P_correction / self.ct_correction_factor_probe)  #- probe * 0x0c + 0x04   -#
                self.parsed_data.insert('P' + str(probe) + '_red', self.raw_data.geti((probe * 0x0c) + 0x08,4) * self.P_correction / self.ct_correction_factor_probe)    #- probe * 0x0c + 0x08   -#
                self.parsed_data.insert('P' + str(probe) + '_blue', self.raw_data.geti((probe * 0x0c) + 0x0c,4) * self.P_correction / self.ct_correction_factor_probe)   #- probe * 0x0c + 0x0c   -#
            end
            probe += 1
        end

        self.parsed_data.insert('V_black', self.raw_data.get(0xe8,2) * self.V_black_correction)  
        self.parsed_data.insert('V_red', self.raw_data.get(0xea,2) * self.V_red_correction)  
        self.parsed_data.insert('V_blue', self.raw_data.get(0xec,2) * self.V_blue_correction)  
        self.parsed_data.insert('frequency', self.freq_correction / self.raw_data.get(0xee,2))  
        self.parsed_data.insert('PhaseAngle_red', (self.raw_data.get(0xf0,2) * 360) / self.raw_data.get(0xee,2)) 
        self.parsed_data.insert('PhaseAngle_blue', (self.raw_data.get(0xf2,2) * 360) / self.raw_data.get(0xee,2)) 

        probe = 0
        while probe < 19
            if probe <= 3
                self.parsed_data.insert('I_' + str(probe), self.raw_data.get((probe * 0x02) + 0xf4,2) * self.I_correction_mains)
            else
                self.parsed_data.insert('I_' + str(probe), self.raw_data.get((probe * 0x02) + 0xf4,2) * self.I_correction_probe )
            end  
            probe += 1
        end
        self.parsed_data.insert('eom', self.raw_data.get(0x11a,2)) #- endofmessage-#
        #- return self.parsed_data -#
    end


    #- trigger a read every second -#
    def every_second()
        if !self.wire return nil end  #- exit if not initialized -#
        self.read_emporia()
    end

    def web_sensor()
        if !self.wire return nil end  #- exit if not initialized -#
        import string
        self.calculate_values()
        var msg = string.format(
                "{s}V_black{m}%.3f V{e}"..
                "{s}Frequency{m}%.2f Hz{e}"..
                "{s}I_A{m}%.3f A{e}",
                self.parsed_data['V_black'], 
                self.parsed_data['frequency'],
                self.parsed_data['I_0'])
        tasmota.web_send_decimal(msg)
    end 
    #- add sensor value to teleperiod -#
    def json_append()
        if !self.wire return nil end  #- exit if not initialized -#
        self.calculate_values()
        #- var msg = "\"EMPORIA\":" .. self.parsed_data.tostring() -#
        var msg = ',"EMPORIA":' + json.dump(self.parsed_data)
        tasmota.response_append(msg)
    end
end #- end class -#

EMPORIA = EMPORIA()
