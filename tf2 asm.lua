console.clear()
package.loaded.asm_thumb_module = nil
package.loaded.tfasm = nil
local tfasm = require 'tfasm'
local asm_thumb_module = require 'asm_thumb_module'
--set up registers as 0
local r = {}
for i = 0,16 do
	r[i] = 0
end


function display(register, r_number, value)
	console.log("PC:"..bizstring.hex(register[15]))
	console.log(bizstring.hex(value)..'\nR'..r_number..': '..bizstring.hex(register[r_number]))
	console.log("DEF: "..asm_thumb_module.get_thumb_instr(value, r))
end

function update_arrays(program_counter, r15_array, pc_array)
	local a = r15_array
	local b = pc_array
	local r15 = bit.band(0xFFFFFFFE,program_counter)
	a[#a+1] = r15
	b[#b+1] = program_counter
	return r15, program_counter, a, b
end


function write_arrays(real_r15, real_pc, sim_r15, sim_pc)
	local file = io.open("tf2 asm.txt","w")
	local line = ""
	local match_r15 = "Yes"
	local match_pc = "Yes"
	io.output(file)
	io.write("Line\tTLog R15\tPC\tSim R15\tPC\tMatch R15\tPC\n")
	for i = 1, #sim_r15 do
		match_r15 = real_r15[i] == sim_r15[i] and "Yes" or "No"
		match_pc = real_pc[i] == sim_pc[i] and "Yes" or "No"
		line = i.."\t"..bizstring.hex(real_r15[i]).."\t"..bizstring.hex(real_pc[i]).."\t"..bizstring.hex(sim_r15[i]).."\t"..bizstring.hex(sim_pc[i]).."\t"..match_r15.."\t"..match_pc.."\n"
		io.write(line)
	end
	io.close(file)
end

function display_registers(registers)
	for i = 0, 16 do
		console.log("r"..i..": "..bizstring.hex(registers[i]))
	end
	console.log("CPSR: "..bizstring.hex(registers.CPSR))
	local N = bit.check(registers.CPSR, 31) and 1 or 0
	local Z = bit.check(registers.CPSR, 30) and 1 or 0
	local C = bit.check(registers.CPSR, 29) and 1 or 0
	local V = bit.check(registers.CPSR, 28) and 1 or 0
	local Q = bit.check(registers.CPSR, 27) and 1 or 0
	console.log("N: "..N.." Z: "..Z.." C: "..C.." V: "..V.." Q: "..Q)
end

savestate.loadslot(5)	--to reset the STR things
local r15 = {}
local pc = {}
local rng1, rng2, rng3 = 0,0,0
local load_target = 0
local current_instr_str = ""
--PC = r15
-- 08102FAB:  0000B510  PUSH    {r4,LR}                   r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:0810F571 r15:08102FAA r16:0000003F
--first we set up all registers
r[0] = 0x00000190
r[1] = 0x085031B8 
r[2] = 0x00000388
r[3] = 0x030034A4
r[4] = 0x000000FF
r[5] = 0x084FE9F0
r[6] = 0x00000000
r[7] = 0x00000000
r[8] = 0x00000000
r[9] = 0x00000000
r[10] = 0x00000000
r[11] = 0x00000000
r[12] = 0x0300040C
r[13] = 0x03007DE0
r[14] = 0x0810F571
r[15] = 0x08102FAA
r[16] = 0x0000003F
r.CPSR = 0x60000012
local r2 = r	--keep copy of originals
--simulate instruction; for some reason instead of #24, its offset #26
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r, false)
-- console.log(bizstring.hex(current_instr_addr))
console.log("Line "..#r15)
console.log(current_instr_str)
display(r, 13, tfasm.pc_value[#r15])


-- 08102FAD:  00001C04  ADD     r4, r0, #0                r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FAC r16:0000003F
--r4 = r0 + 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
-- console.log(bizstring.hex(current_instr_addr))
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])


-- 08102FAF:  00000424  LSL     r4, r4, #16               r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FAE r16:0000003F
--r4 = r4 shift left by 16
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
-- console.log(bizstring.hex(current_instr_addr))
console.log("Line "..#r15)
-- display(r, 4, tfasm.pc_value[#r15])


-- 08102FB1:  00000C24  LSR     r4, r4, #16               r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:01900000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FB0 r16:0000003F
--r4 = r4 shift right by 16
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
-- console.log(bizstring.hex(current_instr_addr))
console.log("Line "..#r15)
-- display(r, 4, tfasm.pc_value[#r15])

--08102FB3:  00004806  LDR     r0, [PC, #24]             r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FB2 r16:0000003F
--load counter again
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
-- console.log(bizstring.hex(current_instr_addr))
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])
--display(register, r_number, PC, value)
-- console.log("Correct value: 0x03000840")
-- console.log("Correct address: 0x08102FCC")


--08102FB5:  00006800  LDR     r0, [r0]                  r0:03000840 r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FB4 r16:0000003F
--load value in r0 to r0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
console.log(bizstring.hex(pc[#pc]))
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
r[0] = r[0] + 1 --counter was incremented a while back
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08102FB7:  0000F041  ORR     r0, r1, #0                r0:00003A0D r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FB6 r16:0000003F
--It's not ORR; it's Jump + LR := PC + OffsetHigh << 12
-- r[14] = 0x08143FB8 --for sanity
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[14], 14, tfasm.pc_value[#r15])

--08102FB9:  0000FD74                                    r0:00003A0D r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08143FB8 r15:08102FB8 r16:0000003F
--Jump + temp := next instruction address; PC := LR + OffsetLow << 1; LR := temp | 1
-- r[15] = 0x08144AA2 --for sanity
-- r[14] = 0x08102FB9 --for sanity
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
offset = 0x0000FD74
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[14], 14, tfasm.pc_value[#r15])

--08144AA3:  0000B570  PUSH    {r4-r6,LR}                r0:00003A0D r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FB9 r15:08144AA2 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r[15] = r[15] + 2
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--08144AA5:  00000400  LSL     r0, r0, #16               r0:00003A0D r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AA4 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AA7:  00000C04  LSR     r4, r0, #16               r0:3A0D0000 r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AA6 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

--08144AA9:  0000490D  LDR     r1, [PC, #52]             r0:3A0D0000 r1:085031B8 r2:00000388 r3:030034A4 r4:00003A0D r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AA8 r16:0000003F
--this loads the address of RNG 1
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])
-- console.log("Correct value: 0x03005E08")
-- console.log("Correct address: 0x08144ADC")

--08144AAB:  00006808  LDR     r0, [r1]                  r0:3A0D0000 r1:03005E08 r2:00000388 r3:030034A4 r4:00003A0D r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AAA r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AAD:  00003001  ADD     r0, r0, #1                r0:0000030F r1:03005E08 r2:00000388 r3:030034A4 r4:00003A0D r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AAC r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AAF:  00006008  STR     r0, [r1]                  r0:00000310 r1:03005E08 r2:00000388 r3:030034A4 r4:00003A0D r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AAE r16:0000003F
--stores r0 back to address of r1;
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
rng1 = r0
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AB1:  00004D0C  LDR     r5, [PC, #48]             r0:00000310 r1:03005E08 r2:00000388 r3:030034A4 r4:00003A0D r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AB0 r16:0000003F
--loads address of RNG 2
--r[5] = 0x03005E0C -- for sanity
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[5], 5, tfasm.pc_value[#r15])
-- console.log("Correct value: 0x03005E0C")
-- console.log("Correct address: 0x08144AE0")

--08144AB3:  00004A0C  LDR     r2, [PC, #48]             r0:00000310 r1:03005E08 r2:00000388 r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AB2 r16:0000003F
--r[2] = 0x081DF49C -- for sanity
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[2], 2, tfasm.pc_value[#r15])
-- console.log("Correct value: 0x081DF49C")
-- console.log("Correct address: 0x00144AE4")

-- --08144AB5:  0000210F  MOV     r1, #15                   r0:00000310 r1:03005E08 r2:081DF49C r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AB4 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08144AB7:  00004008  AND     r0, r0, r1                r0:00000310 r1:0000000F r2:081DF49C r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AB6 r16:0000003F
--rng1 value AND 15
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AB9:  00000080  LSL     r0, r0, #2                r0:00000000 r1:0000000F r2:081DF49C r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AB8 r16:0000003F
--rng1 value AND 15
--followed by left shift twice
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144ABB:  00001880  ADD     r0, r0, r2                r0:00000000 r1:0000000F r2:081DF49C r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144ABA r16:0000003F
--rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144ABD:  00004A0B  LDR     r2, [PC, #44]             r0:081DF49C r1:0000000F r2:081DF49C r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144ABC r16:0000003F
--r[2] = 0x03005E10 --for sanity
--loads the address of RNG 3
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r[2], 2, tfasm.pc_value[#r15])
-- console.log("Correct value: 0x03005E10")
-- console.log("Correct value: 0x08144AE8")

--08144ABF:  00006803  LDR     r3, [r0]                  r0:081DF49C r1:0000000F r2:03005E10 r3:030034A4 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144ABE r16:0000003F
--rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[3], 3, tfasm.pc_value[#r15])

--08144AC1:  00006810  LDR     r0, [r2]                  r0:081DF49C r1:0000000F r2:03005E10 r3:E7479399 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AC0 r16:0000003F
--loads the value at RNG 3
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AC3:  00004043  EOR     r3, r3, r0                r0:691B1B3E r1:0000000F r2:03005E10 r3:E7479399 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AC2 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[3], 3, tfasm.pc_value[#r15])

--08144AC5:  0000602B  STR     r3, [r5]                  r0:691B1B3E r1:0000000F r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AC4 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Store the result to RNG 2
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
rng2 = r[3]
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)	
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AC7:  000043D9  MVN     r1, r3                    r0:691B1B3E r1:0000000F r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AC6 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Store the result to RNG 2
--Bitwise negate this result
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08144AC9:  00002602  MOV     r6, #2                    r0:691B1B3E r1:71A37758 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AC8 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[6], 6, tfasm.pc_value[#r15])

--08144ACB:  00005F90  LDRSH   r0, [r2, r6]              r0:691B1B3E r1:71A37758 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:00000002 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144ACA r16:0000003F
--Take the address of RNG 3 and add 2 to it. It should be (0x03005E12)
--Treat it as an address, and take the value
--Treating the far right bit as the 0th bit, check bit 15. Set bits 16-31 to be the same as bit 15
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144ACD:  00004E08  LDR     r6, [PC, #32]             r0:0000691B r1:71A37758 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:00000002 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144ACC r16:0000003F
--r[6] = 0x55555555 --for sanity
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[6], 6, tfasm.pc_value[#r15])
-- console.log("Correct value: 0x55555555")
-- console.log("Correct value: 0x08144AEC")

--08144ACF:  00001980  ADD     r0, r0, r6                r0:0000691B r1:71A37758 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144ACE r16:0000003F
--Take the address of RNG 3 and add 2 to it. It should be (0x03005E12)
--Treat it as an address, and take the value
--Treating the far right bit as the 0th bit, check bit 15. Set bits 16-31 to be the same as bit 15
--Add 0x55555555 to it. Call this thing temp1
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AD1:  00001809  ADD     r1, r1, r0                r0:5555BE70 r1:71A37758 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AD0 r16:0000003F
--For r1
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Store the result to RNG 2
--Bitwise negate this result
--For r0
--Take the address of RNG 3 and add 2 to it. It should be (0x03005E12)
--Treat it as an address, and take the value
--Treating the far right bit as the 0th bit, check bit 15. Set bits 16-31 to be the same as bit 15
--Add 0x55555555 to it
--With r0, r1, add them together
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08144AD3:  00006011  STR     r1, [r2]                  r0:5555BE70 r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AD2 r16:0000003F
--store that thing from above to rng3
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
rng3 = r[1]
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08144AD5:  00002C00  CMP     r4, #0                    r0:5555BE70 r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AD4 r16:0000003F
--check if the counter from the very beginning is 0
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--08144AD7:  0000D10C  BNE     #+24                      r0:5555BE70 r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AD6 r16:0000003F
--We compared if r4 (game counter) is not 0 by subtracting it. Since it isn't, the Z flag is cleared, and we branch
--r[15] = 0x08144AF2 --for sanity
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--08144AF3:  00008868  LDRH    r0, [r5, #2]              r0:5555BE70 r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AF2 r16:0000003F
--From above:
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Store the result to RNG 2
--Take the address of RNG 2 and add 2 to it. It should be (0x03005E0E)
--Treat it as an address, and take the value
--Treating the far right bit as the 0th bit, check bit 15. Set bits 16-31 to be 0
--This cannot be done, since it happens midframe. Seems to be the same as right shift rng2 to the right 16 times
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AF5:  00004360  MUL     r0, r4, r0                r0:00008E5C r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AF4 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Right shift it 16 times
--Multiply it with the game counter, that has been incremented by 1 at the start
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AF7:  00002800  CMP     r0, #0                    r0:204812AC r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AF6 r16:0000003F
--Check if the above is 0. There's literally no way this could've occurred unless froze the value at 0, it overflowed, or the result before right shift then multiply was < 16 bits
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r, 0, tfasm.pc_value[#r15])

--08144AF9:  0000DA01  BGE     #+2                       r0:204812AC r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AF8 r16:0000003F
--This branches if N == V; ie if it was negative and overflowed, or positive and no overflow
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--08144AFF:  00000C00  LSR     r0, r0, #16               r0:204812AC r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144AFE r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Right shift it 16 times
--Multiply it with the game counter, that has been incremented by 1 at the start
--Right shift it 16 times
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r, 0, tfasm.pc_value[#r15])

--The following has unknown effects
--08144B01:  0000BC70  POP     {r4-r6}                   r0:00002048 r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00003A0D r5:03005E0C r6:55555555 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DC8 r14:08102FB9 r15:08144B00 r16:0000003F
--Load values to r4-r6
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r[4] = 0x00000190
r[5] = 0x084FE9F0
r[6] = 0x00000000
r[15] = r[15] + 2
console.log("Line "..#r15)
-- -- console.log("THIS1:.."..bizstring.hex(load_biz_addr(0x03007FA0,32)))
-- -- console.log("THIS2:.."..bizstring.hex(load_biz_addr(0x03007FA0-4,32)))
-- -- console.log("THIS3:.."..bizstring.hex(load_biz_addr(0x03007FA0-8,32)))
-- -- console.log("THIS4:.."..bizstring.hex(load_biz_addr(0x03007FA0-12,32)))
-- -- display(r[15], 15, tfasm.pc_value[#r15])


--08144B03:  0000BC02  POP     {r1}                      r0:00002048 r1:C6F935C8 r2:03005E10 r3:8E5C88A7 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD4 r14:08102FB9 r15:08144B02 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r[1] = 0x08102FB9
r[15] = r[15] + 2
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08144B05:  00004708  BX      r1                        r0:00002048 r1:08102FB9 r2:03005E10 r3:8E5C88A7 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FB9 r15:08144B04 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08102FBB:  00003401  ADD     r4, r4, #1                r0:00002048 r1:08102FB9 r2:03005E10 r3:8E5C88A7 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FB9 r15:08102FBA r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

--08102FBD:  00001C21  ADD     r1, r4, #0                r0:00002048 r1:08102FB9 r2:03005E10 r3:8E5C88A7 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FB9 r15:08102FBC r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--08102FBF:  0000F0DA                                    r0:00002048 r1:00000191 r2:03005E10 r3:8E5C88A7 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FB9 r15:08102FBE r16:0000003F
--Jump + LR := PC + OffsetHigh << 12
--r[14] = 0x081DCFC0
--r[15] = 0x08102FC0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[14], 14, tfasm.pc_value[#r15])

--08102FC1:  0000FBC8  SMLAL   r0, r0, r8, r0            r0:00002048 r1:00000191 r2:03005E10 r3:8E5C88A7 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:081DCFC0 r15:08102FC0 r16:0000003F
--it's not SMLAL
--Jump + temp := next instruction address; PC := LR + OffsetLow << 1; LR := temp | 1
--r[14] = 0x08102FC1 
--r[15] = 0x081DD752
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[14], 14, tfasm.pc_value[#r15])

--081DD753:  00002301  MOV     r3, #1                    r0:00002048 r1:00000191 r2:03005E10 r3:8E5C88A7 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FC1 r15:081DD752 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)

--081DD755:  00002900  CMP     r1, #0                    r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FC1 r15:081DD754 r16:0000003F
--[[ this is from a bit above
0810F569:  000024FF  MOV     r4, #255                  r0:00000000 r1:085031B8 r2:00000388 r3:030034A4 r4:03000840 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:08151919 r15:0810F568 r16:0000003F
0810F56B:  000020C8  MOV     r0, #200                  r0:00000000 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:08151919 r15:0810F56A r16:0000003F
0810F56D:  00000040  LSL     r0, r0, #1                r0:000000C8 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:08151919 r15:0810F56C r16:0000003F
0810F56F:  0000F7F3                                    r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:08151919 r15:0810F56E r16:0000003F
0810F571:  0000FD1C                                    r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:08102570 r15:0810F570 r16:0000003F
08102FAB:  0000B510  PUSH    {r4,LR}                   r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DE0 r14:0810F571 r15:08102FAA r16:0000003F
08102FAD:  00001C04  ADD     r4, r0, #0                r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FAC r16:0000003F
08102FAF:  00000424  LSL     r4, r4, #16               r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FAE r16:0000003F
08102FB1:  00000C24  LSR     r4, r4, #16               r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:01900000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FB0 r16:0000003F
08102FB3:  00004806  LDR     r0, [PC, #24]             r0:00000190 r1:085031B8 r2:00000388 r3:030034A4 r4:00000190 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:0810F571 r15:08102FB2 r16:0000003F

the blanks are "long branch with links"
r0 was set to 200 for some reason, then shifted left 1 time
it will then be moved to r4, then shifted twice to clear left bits
then it gets pushed to the stack and promptly ignored until now for some reason

]]--
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD757:  0000D05E  BEQ     #+188                     r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FC1 r15:081DD756 r16:0000003F
--well, it's not equal to 0, so nothing happens
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD759:  0000D500  BPL     #+0                       r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FC1 r15:081DD758 r16:0000003F
-- Branch if N clear (positive or zero)
-- If it fails, +2. If it succeeds, + 4
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD75D:  0000B410  PUSH    {r4}                      r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD8 r14:08102FC1 r15:081DD75C r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r[15] = r[15] + 2
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD75F:  0000B401  PUSH    {r0}                      r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD4 r14:08102FC1 r15:081DD75E r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r[15] = r[15] + 2
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD761:  00002800  CMP     r0, #0                    r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD760 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Right shift it 16 times
--Multiply it with the game counter, that has been incremented by 1 at the start
--Right shift it 16 times
--now we are checking if it's 0 for some reason
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD763:  0000D500  BPL     #+0                       r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD762 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD767:  00004288  CMP     r0, r1                    r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD766 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Right shift it 16 times
--Multiply it with the game counter, that has been incremented by 1 at the start
--Right shift it 16 times
--now we are checking if it's 0 for some reason
--now we are checking if it's the same as r1 for some reason
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r[15], 15, tfasm.pc_value[#r15])


--081DD769:  0000D34F  BCC     #+158                     r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD768 r16:0000003F
--branch if carry flag cleared
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- --end of unknown effects 1

--081DD76B:  00002401  MOV     r4, #1                    r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD76A r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

--081DD76D:  00000724  LSL     r4, r4, #28               r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD76C r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

--081DD76F:  000042A1  CMP     r1, r4                    r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD76E r16:0000003F
--compares r1 with r4 for some reason
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--recall r4 was 1,shifted to the left 28 times
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r[15], 15, tfasm.pc_value[#r15])

--081DD771:  0000D204  BCS     #+8                       r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD770 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD773:  00004281  CMP     r1, r0                    r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD772 r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r[15], 15, tfasm.pc_value[#r15])

--081DD775:  0000D202  BCS     #+4                       r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD774 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD777:  00000109  LSL     r1, r1, #4                r0:00002048 r1:00000191 r2:03005E10 r3:00000001 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD776 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--081DD779:  0000011B  LSL     r3, r3, #4                r0:00002048 r1:00001910 r2:03005E10 r3:00000001 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD778 r16:0000003F
--r3 was set to 1 initially a while back above
--we now shift it to the left 4 times
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--081DD77B:  0000E7F8  B       #+-16                     r0:00002048 r1:00001910 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD77A r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD76F:  000042A1  CMP     r1, r4                    r0:00002048 r1:00001910 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD76E r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r[15], 15, tfasm.pc_value[#r15])

--081DD771:  0000D204  BCS     #+8                       r0:00002048 r1:00001910 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD770 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD773:  00004281  CMP     r1, r0                    r0:00002048 r1:00001910 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD772 r16:0000003F
--Rng1 value AND 15
--followed by left shift twice
--followed by + 0x081DF49C (wtf?)
--treat that as a ROM address, and load it's value
--XOR this thing with the value at RNG 3
--Right shift it 16 times
--Multiply it with the game counter, that has been incremented by 1 at the start
--Right shift it 16 times
--now we are checking if it's 0 for some reason
--now we are checking if it's the same as r1 for some reason
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
display(r[15], 15, tfasm.pc_value[#r15])

-- --081DD775:  0000D202  BCS     #+4                       r0:00002048 r1:00001910 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD774 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
-- console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD777:  00000109  LSL     r1, r1, #4                r0:00002048 r1:00001910 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD776 r16:0000003F
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--we now shift it to the left 4 times
--we now shift it to the left 4 times (so 8 in total)
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])

--081DD779:  0000011B  LSL     r3, r3, #4                r0:00002048 r1:00019100 r2:03005E10 r3:00000010 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD778 r16:0000003F
--r3 was set to 1 initially a while back above
--we now shift it to the left 4 times
--we now shift it to the left 4 times (so 8 in total)
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[3], 3, tfasm.pc_value[#r15])

--081DD77B:  0000E7F8  B       #+-16                     r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD77A r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD76F:  000042A1  CMP     r1, r4                    r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD76E r16:0000003F
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--Now shift to the left 4 times, then a comparison, then another left shift 4 times
--recall r4 was 1,shifted to the left 28 times
--We compare these 2 again. why??
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD771:  0000D204  BCS     #+8                       r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD770 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD773:  00004281  CMP     r1, r0                    r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD772 r16:0000003F
--r0 was that ugly RNG mixed with something
--r1 was a constant shifted multiple times
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])
-- write_arrays(tfasm.r15, tfasm.pc, r15, pc)


--081DD775:  0000D202  BCS     #+4                       r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD774 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD77D:  000000E4  LSL     r4, r4, #3                r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:10000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD77C r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

--081DD77F:  000042A1  CMP     r1, r4                    r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD77E r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- --081DD781:  0000D204  BCS     #+8                       r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD780 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD783:  00004281  CMP     r1, r0                    r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD782 r16:0000003F
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

--081DD785:  0000D202  BCS     #+4                       r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD784 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD78D:  00002200  MOV     r2, #0                    r0:00002048 r1:00019100 r2:03005E10 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD78C r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[2], 2, tfasm.pc_value[#r15])

-- 081DD78F:  00004288  CMP     r0, r1                    r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD78E r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD791:  0000D300  BCC     #+0                       r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD790 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD795:  0000084C  LSR     r4, r1, #1                r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:80000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD794 r16:0000003F
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--Now shift to the left 4 times, then a comparison, then another left shift 4 times
--We shift it to the right once, then store it to r4
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

-- 081DD797:  000042A0  CMP     r0, r4                    r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:0000C880 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD796 r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD799:  0000D305  BCC     #+10                      r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:0000C880 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD798 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD7A7:  0000088C  LSR     r4, r1, #2                r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:0000C880 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7A6 r16:0000003F
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--Now shift to the left 4 times, then a comparison, then another left shift 4 times
--We shift it to the right once, then store it to r4
--We ignore r4, then shift r1 to the right twice, then store it to r4; this is the same as above twice
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[4], 4, tfasm.pc_value[#r15])

-- 081DD7A9:  000042A0  CMP     r0, r4                    r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00006440 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7A8 r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- -- 081DD7AB:  0000D305  BCC     #+10                      r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00006440 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7AA r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD7B9:  000008CC  LSR     r4, r1, #3                r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00006440 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7B8 r16:0000003F
--recall r1 was 200,shifted to the left once, then incremented by 1 (401 decimal)
--Now shift to the left 4 times, then a comparison, then another left shift 4 times
--We shift it to the right once, then store it to r4
--We ignore r4, then shift r1 to the right twice, then store it to r4; this is the same as above twice
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD7BB:  000042A0  CMP     r0, r4                    r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7BA r16:0000003F
--N: 1 Z: 0 C: 0 V: 1 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- -- 081DD7BD:  0000D305  BCC     #+10                      r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7BC r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD7CB:  0000469C  MOV     r12, r3                   r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0300040C r13:03007DD0 r14:08102FC1 r15:081DD7CA r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[12], 12, tfasm.pc_value[#r15])

-- 081DD7CD:  00002800  CMP     r0, #0                    r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7CC r16:0000003F
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD7CF:  0000D003  BEQ     #+6                       r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7CE r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

r[3] = 0
-- 081DD7D1:  0000091B  LSR     r3, r3, #4                r0:00002048 r1:00019100 r2:00000000 r3:00000100 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7D0 r16:0000003F
--N: 0 Z: 0 C: 0 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[3], 3, tfasm.pc_value[#r15])


-- 081DD7D3:  0000D001  BEQ     #+2                       r0:00002048 r1:00019100 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7D2 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(r[15]), r)
console.log(current_instr_str)

-- 081DD7D5:  00000909  LSR     r1, r1, #4                r0:00002048 r1:00019100 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7D4 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[1], 1, tfasm.pc_value[#r15])
-- write_arrays(tfasm.r15, tfasm.pc, r15, pc)

-- 081DD7D7:  0000E7D9  B       #+-78                     r0:00002048 r1:00001910 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7D6 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD78D:  00002200  MOV     r2, #0                    r0:00002048 r1:00001910 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD78C r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD78F:  00004288  CMP     r0, r1                    r0:00002048 r1:00001910 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD78E r16:0000003F
--N: 0 Z: 0 C: 1 V: 0 Q: 0
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD791:  0000D300  BCC     #+0                       r0:00002048 r1:00001910 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD790 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD793:  00001A40  SUB     r0, r0, r1                r0:00002048 r1:00001910 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD792 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD795:  0000084C  LSR     r4, r1, #1                r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00003220 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD794 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])

-- 081DD797:  000042A0  CMP     r0, r4                    r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00000C88 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD796 r16:0000003F
r[15], current_instr_addr, r15, pc = update_arrays(tfasm.pc[#r15+1], r15, pc)
r, current_instr_str = asm_thumb_module.do_thumb_instr(asm_thumb_module.pc_to_inst(tfasm.pc[#r15]), r)
console.log("Line "..#r15)
-- display(r[15], 15, tfasm.pc_value[#r15])
display_registers(r)

-- 081DD799:  0000D305  BCC     #+10                      r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00000C88 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD798 r16:0000003F
-- 081DD7A7:  0000088C  LSR     r4, r1, #2                r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00000C88 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7A6 r16:0000003F
-- 081DD7A9:  000042A0  CMP     r0, r4                    r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00000644 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7A8 r16:0000003F
-- 081DD7AB:  0000D305  BCC     #+10                      r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00000644 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7AA r16:0000003F
-- 081DD7AD:  00001B00  SUB     r0, r0, r4                r0:00000738 r1:00001910 r2:00000000 r3:00000010 r4:00000644 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7AC r16:0000003F
-- 081DD7AF:  0000469C  MOV     r12, r3                   r0:000000F4 r1:00001910 r2:00000000 r3:00000010 r4:00000644 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000100 r13:03007DD0 r14:08102FC1 r15:081DD7AE r16:0000003F
-- 081DD7B1:  00002402  MOV     r4, #2                    r0:000000F4 r1:00001910 r2:00000000 r3:00000010 r4:00000644 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7B0 r16:0000003F
-- 081DD7B3:  000041E3  ROR     r3, r4                    r0:000000F4 r1:00001910 r2:00000000 r3:00000010 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7B2 r16:0000003F
-- 081DD7B5:  0000431A  ORR     r2, r2, r3                r0:000000F4 r1:00001910 r2:00000000 r3:00000004 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7B4 r16:0000003F
-- 081DD7B7:  00004663  MOV     r3, r12                   r0:000000F4 r1:00001910 r2:00000004 r3:00000004 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7B6 r16:0000003F
-- 081DD7B9:  000008CC  LSR     r4, r1, #3                r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7B8 r16:0000003F
-- 081DD7BB:  000042A0  CMP     r0, r4                    r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7BA r16:0000003F
-- 081DD7BD:  0000D305  BCC     #+10                      r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7BC r16:0000003F
-- 081DD7CB:  0000469C  MOV     r12, r3                   r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7CA r16:0000003F
-- 081DD7CD:  00002800  CMP     r0, #0                    r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7CC r16:0000003F
-- 081DD7CF:  0000D003  BEQ     #+6                       r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7CE r16:0000003F
-- 081DD7D1:  0000091B  LSR     r3, r3, #4                r0:000000F4 r1:00001910 r2:00000004 r3:00000010 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7D0 r16:0000003F
-- 081DD7D3:  0000D001  BEQ     #+2                       r0:000000F4 r1:00001910 r2:00000004 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7D2 r16:0000003F
-- 081DD7D5:  00000909  LSR     r1, r1, #4                r0:000000F4 r1:00001910 r2:00000004 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7D4 r16:0000003F
-- 081DD7D7:  0000E7D9  B       #+-78                     r0:000000F4 r1:00000191 r2:00000004 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD7D6 r16:0000003F
-- 081DD78D:  00002200  MOV     r2, #0                    r0:000000F4 r1:00000191 r2:00000004 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD78C r16:0000003F
-- 081DD78F:  00004288  CMP     r0, r1                    r0:000000F4 r1:00000191 r2:00000000 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD78E r16:0000003F
-- 081DD791:  0000D300  BCC     #+0                       r0:000000F4 r1:00000191 r2:00000000 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD790 r16:0000003F
-- 081DD795:  0000084C  LSR     r4, r1, #1                r0:000000F4 r1:00000191 r2:00000000 r3:00000001 r4:00000322 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD794 r16:0000003F
-- 081DD797:  000042A0  CMP     r0, r4                    r0:000000F4 r1:00000191 r2:00000000 r3:00000001 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD796 r16:0000003F
-- 081DD799:  0000D305  BCC     #+10                      r0:000000F4 r1:00000191 r2:00000000 r3:00000001 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD798 r16:0000003F
-- 081DD79B:  00001B00  SUB     r0, r0, r4                r0:000000F4 r1:00000191 r2:00000000 r3:00000001 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD79A r16:0000003F
-- 081DD79D:  0000469C  MOV     r12, r3                   r0:0000002C r1:00000191 r2:00000000 r3:00000001 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000010 r13:03007DD0 r14:08102FC1 r15:081DD79C r16:0000003F
-- 081DD79F:  00002401  MOV     r4, #1                    r0:0000002C r1:00000191 r2:00000000 r3:00000001 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD79E r16:0000003F
-- 081DD7A1:  000041E3  ROR     r3, r4                    r0:0000002C r1:00000191 r2:00000000 r3:00000001 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7A0 r16:0000003F
-- 081DD7A3:  0000431A  ORR     r2, r2, r3                r0:0000002C r1:00000191 r2:00000000 r3:80000000 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7A2 r16:0000003F
-- 081DD7A5:  00004663  MOV     r3, r12                   r0:0000002C r1:00000191 r2:80000000 r3:80000000 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7A4 r16:0000003F
-- 081DD7A7:  0000088C  LSR     r4, r1, #2                r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7A6 r16:0000003F
-- 081DD7A9:  000042A0  CMP     r0, r4                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000064 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7A8 r16:0000003F
-- 081DD7AB:  0000D305  BCC     #+10                      r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000064 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7AA r16:0000003F
-- 081DD7B9:  000008CC  LSR     r4, r1, #3                r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000064 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7B8 r16:0000003F
-- 081DD7BB:  000042A0  CMP     r0, r4                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7BA r16:0000003F
-- 081DD7BD:  0000D305  BCC     #+10                      r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7BC r16:0000003F
-- 081DD7CB:  0000469C  MOV     r12, r3                   r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7CA r16:0000003F
-- 081DD7CD:  00002800  CMP     r0, #0                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7CC r16:0000003F
-- 081DD7CF:  0000D003  BEQ     #+6                       r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7CE r16:0000003F
-- 081DD7D1:  0000091B  LSR     r3, r3, #4                r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7D0 r16:0000003F
-- 081DD7D3:  0000D001  BEQ     #+2                       r0:0000002C r1:00000191 r2:80000000 r3:00000000 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7D2 r16:0000003F
-- 081DD7D9:  0000240E  MOV     r4, #14                   r0:0000002C r1:00000191 r2:80000000 r3:00000000 r4:00000032 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7D8 r16:0000003F
-- 081DD7DB:  00000724  LSL     r4, r4, #28               r0:0000002C r1:00000191 r2:80000000 r3:00000000 r4:0000000E r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7DA r16:0000003F
-- 081DD7DD:  00004022  AND     r2, r2, r4                r0:0000002C r1:00000191 r2:80000000 r3:00000000 r4:E0000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7DC r16:0000003F
-- 081DD7DF:  0000D014  BEQ     #+40                      r0:0000002C r1:00000191 r2:80000000 r3:00000000 r4:E0000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7DE r16:0000003F
-- 081DD7E1:  00004663  MOV     r3, r12                   r0:0000002C r1:00000191 r2:80000000 r3:00000000 r4:E0000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7E0 r16:0000003F
-- 081DD7E3:  00002403  MOV     r4, #3                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:E0000000 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7E2 r16:0000003F
-- 081DD7E5:  000041E3  ROR     r3, r4                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000003 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7E4 r16:0000003F
-- 081DD7E7:  0000421A  TST     r2, r3                    r0:0000002C r1:00000191 r2:80000000 r3:20000000 r4:00000003 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7E6 r16:0000003F
-- 081DD7E9:  0000D001  BEQ     #+2                       r0:0000002C r1:00000191 r2:80000000 r3:20000000 r4:00000003 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7E8 r16:0000003F
-- 081DD7EF:  00004663  MOV     r3, r12                   r0:0000002C r1:00000191 r2:80000000 r3:20000000 r4:00000003 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7EE r16:0000003F
-- 081DD7F1:  00002402  MOV     r4, #2                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000003 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7F0 r16:0000003F
-- 081DD7F3:  000041E3  ROR     r3, r4                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7F2 r16:0000003F
-- 081DD7F5:  0000421A  TST     r2, r3                    r0:0000002C r1:00000191 r2:80000000 r3:40000000 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7F4 r16:0000003F
-- 081DD7F7:  0000D001  BEQ     #+2                       r0:0000002C r1:00000191 r2:80000000 r3:40000000 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7F6 r16:0000003F
-- 081DD7FD:  00004663  MOV     r3, r12                   r0:0000002C r1:00000191 r2:80000000 r3:40000000 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7FC r16:0000003F
-- 081DD7FF:  00002401  MOV     r4, #1                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000002 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD7FE r16:0000003F
-- 081DD801:  000041E3  ROR     r3, r4                    r0:0000002C r1:00000191 r2:80000000 r3:00000001 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD800 r16:0000003F
-- 081DD803:  0000421A  TST     r2, r3                    r0:0000002C r1:00000191 r2:80000000 r3:80000000 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD802 r16:0000003F
-- 081DD805:  0000D001  BEQ     #+2                       r0:0000002C r1:00000191 r2:80000000 r3:80000000 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD804 r16:0000003F
-- 081DD807:  0000084C  LSR     r4, r1, #1                r0:0000002C r1:00000191 r2:80000000 r3:80000000 r4:00000001 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD806 r16:0000003F
-- 081DD809:  00001900  ADD     r0, r0, r4                r0:0000002C r1:00000191 r2:80000000 r3:80000000 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD808 r16:0000003F
-- 081DD80B:  0000BC10  POP     {r4}                      r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:000000C8 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD0 r14:08102FC1 r15:081DD80A r16:0000003F
-- 081DD80D:  00002C00  CMP     r4, #0                    r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:00002048 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD4 r14:08102FC1 r15:081DD80C r16:0000003F
-- 081DD80F:  0000D500  BPL     #+0                       r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:00002048 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD4 r14:08102FC1 r15:081DD80E r16:0000003F
-- 081DD813:  0000BC10  POP     {r4}                      r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:00002048 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD4 r14:08102FC1 r15:081DD812 r16:0000003F
-- 081DD815:  000046F7  MOV     PC, LR                    r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD8 r14:08102FC1 r15:081DD814 r16:0000003F
-- 08102FC3:  00000400  LSL     r0, r0, #16               r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD8 r14:08102FC1 r15:08102FC2 r16:0000003F
-- 08102FC5:  00000C00  LSR     r0, r0, #16               r0:00F40000 r1:00000191 r2:80000000 r3:80000000 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD8 r14:08102FC1 r15:08102FC4 r16:0000003F
-- 08102FC7:  0000BC10  POP     {r4}                      r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:00000191 r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DD8 r14:08102FC1 r15:08102FC6 r16:0000003F
-- 08102FC9:  0000BC02  POP     {r1}                      r0:000000F4 r1:00000191 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DDC r14:08102FC1 r15:08102FC8 r16:0000003F
-- 08102FCB:  00004708  BX      r1                        r0:000000F4 r1:0810F571 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:08102FCA r16:0000003F
-- 0810F573:  00000400  LSL     r0, r0, #16               r0:000000F4 r1:0810F571 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F572 r16:0000003F
-- 0810F575:  00000C01  LSR     r1, r0, #16               r0:00F40000 r1:0810F571 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F574 r16:0000003F
-- 0810F577:  00002931  CMP     r1, #49                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F576 r16:0000003F
-- 0810F579:  0000D815  BHI     #+42                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F578 r16:0000003F
-- 0810F5A7:  00002949  CMP     r1, #73                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F5A6 r16:0000003F
-- 0810F5A9:  0000D817  BHI     #+46                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F5A8 r16:0000003F
-- 0810F5DB:  00002957  CMP     r1, #87                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F5DA r16:0000003F
-- 0810F5DD:  0000D815  BHI     #+42                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F5DC r16:0000003F
-- 0810F60B:  00002959  CMP     r1, #89                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F60A r16:0000003F
-- 0810F60D:  0000D817  BHI     #+46                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F60C r16:0000003F
-- 0810F63F:  0000295D  CMP     r1, #93                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F63E r16:0000003F
-- 0810F641:  0000D815  BHI     #+42                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F640 r16:0000003F
-- 0810F66F:  00002961  CMP     r1, #97                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F66E r16:0000003F
-- 0810F671:  0000D817  BHI     #+46                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F670 r16:0000003F
-- 0810F6A3:  00002963  CMP     r1, #99                   r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F6A2 r16:0000003F
-- 0810F6A5:  0000D815  BHI     #+42                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F6A4 r16:0000003F
-- 0810F6D3:  00002965  CMP     r1, #101                  r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F6D2 r16:0000003F
-- 0810F6D5:  0000D817  BHI     #+46                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F6D4 r16:0000003F
-- 0810F707:  00002967  CMP     r1, #103                  r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F706 r16:0000003F
-- 0810F709:  0000D815  BHI     #+42                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F708 r16:0000003F
-- 0810F737:  00002969  CMP     r1, #105                  r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F736 r16:0000003F
-- 0810F739:  0000D817  BHI     #+46                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F738 r16:0000003F
-- 0810F76B:  0000296B  CMP     r1, #107                  r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F76A r16:0000003F
-- 0810F76D:  0000D815  BHI     #+42                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F76C r16:0000003F
-- 0810F79B:  0000296D  CMP     r1, #109                  r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F79A r16:0000003F
-- 0810F79D:  0000D817  BHI     #+46                      r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007DE0 r14:08102FC1 r15:0810F79C r16:0000003F
-- 0000001C:  EA000042  B       #+264                     r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007FA0 r14:0810F7D0 r15:0000001C r16:20000032
-- 0000012C:  E92D500F  PUSH    {r0-r3,r12,LR}            r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007FA0 r14:0810F7D0 r15:0000012C r16:20000032
-- 00000130:  E3A00301  MOV     r0, #0x4000000            r0:00F40000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:0810F7D0 r15:00000130 r16:20000032
-- 00000134:  E28FE000  ADR     LR, #+0                   r0:04000000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:0810F7D0 r15:00000134 r16:20000032
-- 00000138:  E510F004  LDR     PC, [r0, #-4]             r0:04000000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:00000138 r16:20000032
-- 03002CA4:  E3A03301  MOV     r3, #0x4000000            r0:04000000 r1:000000F4 r2:80000000 r3:80000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:03002CA4 r16:20000032
-- 03002CA8:  E2833C02  ADD     r3, r3, #512              r0:04000000 r1:000000F4 r2:80000000 r3:04000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:03002CA8 r16:20000032
-- 03002CAC:  E5932000  LDR     r2, [r3]                  r0:04000000 r1:000000F4 r2:80000000 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:03002CAC r16:20000032
-- 03002CB0:  E1D310B8  LDRH    r1, [r3, #8]              r0:04000000 r1:000000F4 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:03002CB0 r16:20000032
-- 03002CB4:  E14F0000  SMLAL   r0, PC, r0, r0            r0:04000000 r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:03002CB4 r16:20000032
-- 03002CB8:  E92D400F  PUSH    {r0-r3,LR}                r0:2000003F r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F88 r14:00000138 r15:03002CB8 r16:20000032
-- 03002CBC:  E3A00001  MOV     r0, #1                    r0:2000003F r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F74 r14:00000138 r15:03002CBC r16:20000032
-- 03002CC0:  E1C300B8  STRH    r0, [r3, #8]              r0:00000001 r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F74 r14:00000138 r15:03002CC0 r16:20000032
-- 03002CC4:  E0021822  AND     r1, r2, r2, LSR #16       r0:00000001 r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F74 r14:00000138 r15:03002CC4 r16:20000032
-- 03002CC8:  E3A0C000  MOV     r12, #0                   r0:00000001 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000001 r13:03007F74 r14:00000138 r15:03002CC8 r16:20000032
-- 03002CCC:  E21100C0  ANDS    r0, r1, #192              r0:00000001 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000000 r13:03007F74 r14:00000138 r15:03002CCC r16:20000032
-- 03002CD0:  1A000027  BNE     #+156                     r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000000 r13:03007F74 r14:00000138 r15:03002CD0 r16:20000032
-- 03002CD4:  E28CC004  ADD     r12, r12, #4              r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000000 r13:03007F74 r14:00000138 r15:03002CD4 r16:20000032
-- 03002CD8:  E2110001  ANDS    r0, r1, #1                r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000004 r13:03007F74 r14:00000138 r15:03002CD8 r16:20000032
-- 03002CDC:  1A000024  BNE     #+144                     r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000004 r13:03007F74 r14:00000138 r15:03002CDC r16:20000032
-- 03002CE0:  E28CC004  ADD     r12, r12, #4              r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000004 r13:03007F74 r14:00000138 r15:03002CE0 r16:20000032
-- 03002CE4:  E2110004  ANDS    r0, r1, #4                r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000008 r13:03007F74 r14:00000138 r15:03002CE4 r16:20000032
-- 03002CE8:  1A000021  BNE     #+132                     r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000008 r13:03007F74 r14:00000138 r15:03002CE8 r16:20000032
-- 03002CEC:  E28CC004  ADD     r12, r12, #4              r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:00000008 r13:03007F74 r14:00000138 r15:03002CEC r16:20000032
-- 03002CF0:  E2110002  ANDS    r0, r1, #2                r0:00000000 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002CF0 r16:20000032
-- 03002CF4:  1A00001E  BNE     #+120                     r0:00000002 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002CF4 r16:20000032
-- 03002D74:  E1C300B2  STRH    r0, [r3, #2]              r0:00000002 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D74 r16:20000032
-- 03002D78:  E3A01D9B  MOV     r1, #0x26c0               r0:00000002 r1:00000002 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D78 r16:20000032
-- 03002D7C:  E1C22000  BIC     r2, r2, r0                r0:00000002 r1:000026C0 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D7C r16:20000032
-- 03002D80:  E0011002  AND     r1, r1, r2                r0:00000002 r1:000026C0 r2:00022601 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D80 r16:20000032
-- 03002D84:  E1C310B0  STRH    r1, [r3]                  r0:00000002 r1:00002600 r2:00022601 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D84 r16:20000032
-- 03002D88:  E10F3000  SMLABB  PC, r0, r0, r3            r0:00000002 r1:00002600 r2:00022601 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D88 r16:20000032
-- 03002D8C:  E3C330DF  BIC     r3, r3, #223              r0:00000002 r1:00002600 r2:00022601 r3:20000092 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D8C r16:20000092
-- 03002D90:  E383301F  ORR     r3, r3, #31               r0:00000002 r1:00002600 r2:00022601 r3:20000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D90 r16:20000092
-- 03002D94:  E129F003                                    r0:00000002 r1:00002600 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002D94 r16:20000092
-- 03002D98:  E59F1038  LDR     r1, [PC, #56]             r0:00000002 r1:00002600 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002D98 r16:2000001F
-- 03002D9C:  E081100C  ADD     r1, r1, r12               r0:00000002 r1:03004380 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002D9C r16:2000001F
-- 03002DA0:  E5910000  LDR     r0, [r1]                  r0:00000002 r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002DA0 r16:2000001F
-- 03002DA4:  E92D4000  PUSH    {LR}                      r0:08127741 r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002DA4 r16:2000001F
-- 03002DA8:  E28FE000  ADR     LR, #+0                   r0:08127741 r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DDC r14:08102FC1 r15:03002DA8 r16:2000001F
-- 03002DAC:  E12FFF10  BX      r0                        r0:08127741 r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DDC r14:03002DAC r15:03002DAC r16:2000001F
-- 08127743:  0000B500  PUSH    {LR}                      r0:08127741 r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DDC r14:03002DAC r15:08127742 r16:2000001F
-- 08127745:  00004804  LDR     r0, [PC, #16]             r0:08127741 r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:03002DAC r15:08127744 r16:2000001F
-- 08127747:  00006800  LDR     r0, [r0]                  r0:030034BC r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:03002DAC r15:08127746 r16:2000001F
-- 08127749:  0000F0B5                                    r0:0812775D r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:03002DAC r15:08127748 r16:2000001F
-- 0812774B:  0000FF99                                    r0:0812775D r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:081DC74A r15:0812774A r16:2000001F
-- 081DD67F:  00004700  BX      r0                        r0:0812775D r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:0812774B r15:081DD67E r16:2000001F
-- 0812775F:  00004770  BX      LR                        r0:0812775D r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:0812774B r15:0812775E r16:2000001F
-- 0812774D:  00004903  LDR     r1, [PC, #12]             r0:0812775D r1:0300438C r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:0812774B r15:0812774C r16:2000001F
-- 0812774F:  00002002  MOV     r0, #2                    r0:0812775D r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:0812774B r15:0812774E r16:2000001F
-- 08127751:  00008008  STRH    r0, [r1]                  r0:00000002 r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:0812774B r15:08127750 r16:2000001F
-- 08127753:  0000BC01  POP     {r0}                      r0:00000002 r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DD8 r14:0812774B r15:08127752 r16:2000001F
-- 08127755:  00004700  BX      r0                        r0:03002DAC r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DDC r14:0812774B r15:08127754 r16:2000001F
-- 03002DB0:  E8BD4000  POP     {LR}                      r0:03002DAC r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DDC r14:0812774B r15:03002DB0 r16:2000001F
-- 03002DB4:  E10F3000  SMLABB  PC, r0, r0, r3            r0:03002DAC r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002DB4 r16:2000001F
-- 03002DB8:  E3C330DF  BIC     r3, r3, #223              r0:03002DAC r1:04000202 r2:00022601 r3:2000001F r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002DB8 r16:2000001F
-- 03002DBC:  E3833092  ORR     r3, r3, #146              r0:03002DAC r1:04000202 r2:00022601 r3:20000000 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002DBC r16:2000001F
-- 03002DC0:  E129F003                                    r0:03002DAC r1:04000202 r2:00022601 r3:20000092 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007DE0 r14:08102FC1 r15:03002DC0 r16:2000001F
-- 03002DC4:  E8BD400F  POP     {r0-r3,LR}                r0:03002DAC r1:04000202 r2:00022601 r3:20000092 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F74 r14:00000138 r15:03002DC4 r16:20000092
-- 03002DC8:  E1C320B0  STRH    r2, [r3]                  r0:2000003F r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F88 r14:00000138 r15:03002DC8 r16:20000092
-- 03002DCC:  E1C310B8  STRH    r1, [r3, #8]              r0:2000003F r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F88 r14:00000138 r15:03002DCC r16:20000092
-- 03002DD0:  E169F000                                    r0:2000003F r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F88 r14:00000138 r15:03002DD0 r16:20000092
-- 03002DD4:  E12FFF1E  BX      LR                        r0:2000003F r1:00000001 r2:00022603 r3:04000200 r4:000000FF r5:084FE9F0 r6:00000000 r7:00000000 r8:00000000 r9:00000000 r10:00000000 r11:00000000 r12:0000000C r13:03007F88 r14:00000138 r15:03002DD4 r16:20000092
