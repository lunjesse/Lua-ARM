local hex = bizstring.hex
local format = string.format
local utility = require('utility')
local asm_thumb_module = {}

function asm_thumb_module.pc_to_inst(pc)
	--given program counter return instruction
	--ROM is always 16 bit Thumb mode.
	--Everywhere else is 32 bit ARM
	local address = bit.band(0xFFFFFFFE,pc)	--Mask away bit 0, since it's used to determine ARM/THUMB mode
	if address > 0x08000000 then
	--THUMB instruction addresses are 2 bytes before PC value; ARM is 4
		address = address - 2
	else
		address = address - 4
	end
	size = pc > 0x08000000 and 16 or 32	--if in other locations, its 32 bit ARM. Else 16 bit THUMB
	return utility.load_biz_addr(address,size)
end

function BX(Rs, CPSR)
--Implement "Entering THUMB state"
--Bit 5 of CPSR is the THUMB flag; 0 for ARM, 1 for THUMB
	CPSR = (Rs % 2 == 1) and bit.set(CPSR, 5) or bit.clear(CPSR, 5)
--[[From manual:
When R15 is read, bit[0] is zero and bits[31:1] contain the PC. When R15 is written, bit[0] is IGNORED and
bits[31:1] are written to the PC. Depending on how it is used, the value of the PC is either the address of the
instruction plus 4 or is UNPREDICTABLE.

Based on the trace log, it seems it's always zero'd
]]--
	return bit.band(0xFFFFFFFE,Rs), CPSR
end


function BL(offset,LR,PC,H_flag)
	--don't set flags
	--long branch with link
	if H_flag == 0 then
		-- console.log(hex(bit.lshift(offset,12)))
		--only sign extend if H is 0
		local signed = bit.check(offset,10)
		if signed then
			offset = bit.bor(-2048,offset)	-- This is FFFF F800 in doubleword
		end
		local r14 = PC + bit.lshift(offset,12) + 2
		r14 = signed and r14 - 0x100000000 or r14	--sign extend messes bit 32 up
		return r14, PC
	else
		local temp = PC
		return bit.bor(temp,1), bit.lshift(offset,1) + LR
	end
end

--[[ PUSH only without STMIA
function PUSH(R, RList, Registers)
	local SP = Registers[13]
	local end_addr = SP - 4
	local num = 0
	--we need to know how many registers to store first
	for i = 0, 7 do
		num = (bit.rshift(RList, i) % 2 == 1) and (num + 1) or num
	end
	--use number of registers for start address
	local start_addr = SP - 4 * (R + num)
	console.log(hex(start_addr))
	local addr = start_addr
	for i = 0, 7 do
		if bit.rshift(RList, i) % 2 == 1 then	--its this, or ugly bit.check(RList, i)
			utility.write_biz_addr(addr, Registers[i], 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		utility.write_biz_addr(addr, SP, 32)
		addr = addr + 4
	end
	if (addr - 4) ~= end_addr then console.log("PUSH ERROR:\nAddress is "..hex(addr).." but End is: "..hex(end_addr)) end
	local temp = Registers
	temp[13] = start_addr
	return temp
end
]]--

--[[POP only without LDMIA
function POP(R, RList, Registers)
	local temp = Registers
	local SP = Registers[13]
	local start_addr = SP
	local num = 0
	--we need to know how many registers to store first
	for i = 0, 7 do
		num = (bit.rshift(RList, i) % 2 == 1) and (num + 1) or num
	end
	local end_addr = SP + 4 * (R + num)
	local addr = start_addr
	for i = 0, 7 do
		if bit.rshift(RList, i) % 2 == 1 then	--its this, or ugly bit.check(RList, i)
			temp[i] = utility.load_biz_addr(addr, 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		temp[15] = bit.band(0xFFFFFFFE, utility.load_biz_addr(addr, 32))	--Mask away bit 0, since it's used to determine ARM/THUMB mode
		addr = addr + 4
	end
	if addr ~= end_addr then console.log("POP ERROR\nAddress is "..hex(addr).." but End is: "..hex(end_addr)) end
	temp[13] = end_addr
	return temp
end]]--

--[[
STMIA
MemoryAccess(B-bit, E-bit)
processor_id = ExecutingProcessor()
start_address = Rn
end_address = Rn + (Number_Of_Set_Bits_In(register_list) * 4) - 4
address = start_address
for i = 0 to 7
	if register_list[i] == 1
		Memory[address,4] = Ri
		if Shared(address then /* from ARMv6 */
			physical_address = TLB(address
			ClearExclusiveByAddress(physical_address,4)
		address = address + 4
assert end_address == address - 4
Rn = Rn + (Number_Of_Set_Bits_In(register_list) * 4)

PUSH
MemoryAccess(B-bit, E-bit)
start_address = SP - 4*(R + Number_Of_Set_Bits_In(register_list))
end_address = SP - 4
address = start_address
for i = 0 to 7
	if register_list[i] == 1
		Memory[address,4] = Ri
		address = address + 4
if R == 1
	Memory[address,4] = LR
	address = address + 4
assert end_address == address - 4
SP = SP - 4*(R + Number_Of_Set_Bits_In(register_list))
if (CP15_reg1_Ubit == 1) /* ARMv6 */
	if Shared(address then /* from ARMv6 */
		physical_address = TLB(address
		ClearExclusiveByAddress(physical_address, size)


LDMIA
MemoryAccess(B-bit, E-bit)
start_address = Rn
end_address = Rn + (Number_Of_Set_Bits_In(register_list) * 4) - 4
address = start_address
for i = 0 to 7
	if register_list[i] == 1
		Ri = Memory[address,4]
		address = address + 4
assert end_address == address - 4
Rn = Rn + (Number_Of_Set_Bits_In(register_list) * 4)


POP
MemoryAccess(B-bit, E-bit)
start_address = SP
end_address = SP + 4*(R + Number_Of_Set_Bits_In(register_list))
address = start_address

for i = 0 to 7
	if register_list[i] == 1 then
		Ri = Memory[address,4]
		address = address + 4

	if R == 1 then
		value = Memory[address,4]
		PC = value AND 0xFFFFFFFE
		if (architecture version 5 or above) then
			T Bit = value[0]
		address = address + 4
		
assert end_address = address
SP = end_address

]]--

function PUSH(R, Rn, RList, registers)
--Let's try to combine STMIA and PUSH
--[[
STMIA
start_address = Rn
end_address = Rn + (Number_Of_Set_Bits_In(register_list) * 4) - 4
PUSH
start_address = SP - 4*(R + Number_Of_Set_Bits_In(register_list))
end_address = SP - 4	
]]--
	local Ri = registers[Rn]
	local start_addr = 0
	local end_addr = 0
	local num = 0
	--we need to know how many registers to store first
	for i = 0, 7 do
		num = (bit.rshift(RList, i) % 2 == 1) and (num + 1) or num
	end
	--STMIA and PUSH uses different start/ends, so we need 2 cases
	if (Rn ~= 13) then	--STMIA
		start_addr = Ri
		end_addr = Ri + (num * 4) - 4
	else	--PUSH
		start_addr = Ri - 4 * (R + num)
		end_addr = Ri - 4
	end
	-- console.log(hex(start_addr))
	local addr = start_addr
	for i = 0, 7 do
		if bit.rshift(RList, i) % 2 == 1 then	--its this, or ugly bit.check(RList, i)
			utility.write_biz_addr(addr, registers[i], 32)
			addr = addr + 4
		end
	end
	if R == 1 then --Push R14 (Link Register) to stack
		utility.write_biz_addr(addr, registers[14], 32)
		addr = addr + 4
	end
	if (addr - 4) ~= end_addr then console.log("PUSH ERROR:\nAddress is "..hex(addr).." but End is: "..hex(end_addr)) end
	--[[
STMIA
Rn = Rn + (Number_Of_Set_Bits_In(register_list) * 4)
This is end_addr + 4
PUSH
SP = SP - 4*(R + Number_Of_Set_Bits_In(register_list))
This is start_addr
]]--
	local temp = registers
	temp[Rn] = (Rn == 13) and start_addr or end_addr + 4
	return temp
end

function STMIA(Rb, Rlist, registers)
	local temp_array = registers
	return PUSH(0, Rb, RList, registers)
end
function POP(R, Rn, RList, registers)
--Let's try to combine LDMIA and POP
	local temp_array = registers
	local Ri = registers[Rn]
	local start_addr = Ri
	local num = 0
	--we need to know how many registers to store first
	for i = 0, 7 do
		num = (bit.rshift(RList, i) % 2 == 1) and (num + 1) or num
	end
	--If R isn't 13, this becomes LDMIA, so we also need to subtract 4
	local end_addr = Ri + 4 * (R + num)
	if (Rn ~= 13) then end_addr = end_addr - 4 end
	local addr = start_addr
	for i = 0, 7 do
		if bit.rshift(RList, i) % 2 == 1 then	--its this, or ugly bit.check(RList, i)
			temp_array[i] = utility.load_biz_addr(addr, 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		temp_array[15] = bit.band(0xFFFFFFFE, utility.load_biz_addr(addr, 32))	--Mask away bit 0, since it's used to determine ARM/THUMB mode
		addr = addr + 4
	end
	--LDMIA's end address is addr - 4, while POP is just addr
	local end_cond = true
	local this = 4
	if (Rn == 13) then
		end_cond = (end_addr == addr)
		this = 0
	else
		end_cond = (end_addr == (addr - 4))
	end
	if end_cond == false then console.log("POP ERROR\nAddress is "..hex(addr).." but End is: "..hex(end_addr)) end
	temp_array[Rn] = end_addr + this	--LDMIA subtracted 4 at the beginning, need to add it back. Don't do it for POP
	return temp_array
end

function LDMIA(Rb, Rlist, registers)
	local temp_array = registers
	return POP(0, Rb, RList, registers)
end

function SWI()
--[[
if ConditionPassed(cond) then
R14_svc = address of next instruction after the SWI instruction
SPSR_svc = CPSR
CPSR[4:0] = 0b10011 /* Enter Supervisor mode */
CPSR[5] = 0 /* Execute in ARM state */
/* CPSR[6] is unchanged */
CPSR[7] = 1 /* Disable normal interrupts */
 /* CPSR[8] is unchanged */
 CPSR[9] = CP15_reg1_EEbit
if high vectors configured then
PC = 0xFFFF0008
else
PC = 0x00000008
]]--
end

function thumb_format1(OP, Rd, Rs, Offset5, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 1: move shifted register: ", ""}
	local end_string = " Rd, Rs, #Offset5\nRd: "..Rd.." ("..hex(registers[Rd])..") Rs: "..Rs.." ("..hex(registers[Rs])..") Offset5: "..Offset5
	if OP == 0 then
	--Shift Rs left by a 5-bit immediate value and store the result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.LSL(registers[Rs], Offset5, CPSR)
		return_string[1] = return_string[1].."LSL"..end_string
		return_string[2] = "LSL     r"..Rd..", r"..Rs..", #"..Offset5
	elseif OP == 1 then
	--Perform logical shift right on Rs by a 5-bit immediate value and store the result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.LSR1(registers[Rs], Offset5, CPSR)
		return_string[1] = return_string[1].."LSR"..end_string
		return_string[2] = "LSR     r"..Rd..", r"..Rs..", #"..Offset5
	elseif OP == 2 then
	--Perform arithmetic shift right on Rs by a 5-bit immediate value and store the result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.ASR1(registers[Rs], Offset5, CPSR)
		return_string[1] = return_string[1].."ASR"..end_string
		return_string[2] = "ASR     r"..Rd..", r"..Rs..", #"..Offset5
	else
		return_string[1] = "Format 1 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format2(OP, Rd, Rs, Rn, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 2: add/subtract: ", ""}
	local end_string = " Rd, Rs, Rn\nRd: "..Rd.." ("..hex(registers[Rd])..") Rs: "..Rs.." ("..hex(registers[Rs])..")"
	local end_string2 = end_string.." Rn: "..Rn.." ("..hex(registers[Rn])..")"
	local Offset3 = Rn	--Make it explicit this is the same
	local end_string3 = end_string.." Offset3: "..Offset3	--its 3 bits, no need to make it hex
	if OP == 0 then
--Add contents of Rn to contents of Rs. Place result in Rd
		temp_array[Rd], temp_array.CPSR = utility.ADD(registers[Rs], registers[Rn], CPSR)
		return_string[1] = return_string[1].."ADD"..end_string2
		return_string[2] = "ADD     r"..Rd..", r"..Rs..", r"..Rn
	elseif OP == 1 then
--Subtract contents of Rn from contents of Rs. Place result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.SUB(registers[Rs], registers[Rn], CPSR)
		return_string[1] = return_string[1].."SUB"..end_string2
		return_string[2] = "SUB     r"..Rd..", r"..Rs..", r"..Rn
	elseif OP == 2 then
--Add 3-bit immediate value to contents of Rs. Place result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.ADD(registers[Rs], Offset3, CPSR)
		return_string[1] = return_string[1].."ADD"..end_string3
		return_string[2] = "ADD     r"..Rd..", r"..Rs..", #"..Offset3
	elseif OP == 3 then
--Subtract 3-bit immediate value from contents of Rs. Place result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.SUB(registers[Rs], Offset3, CPSR)
		return_string[1] = return_string[1].."SUB"..end_string3
		return_string[2] = "SUB     r"..Rd..", r"..Rs..", #"..Offset3
	else
		return_string[1] = "Format 2 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format3(OP, Rd, Offset8, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 3: move/compare/add/subtract immediate: ", ""}
	local end_string = " Rd, #Offset8\nRd: "..Rd.." ("..hex(registers[Rd])..") Offset8: "..Offset8
	if OP == 0 then
	--Move 8-bit immediate value into Rd.
		temp_array[Rd], temp_array.CPSR = utility.MOV(_, Offset8, CPSR)
		return_string[1] = return_string[1].."MOV"..end_string
		return_string[2] = "MOV     r"..Rd..", #"..Offset8
	elseif OP == 1 then
	--Compare contents of Rd with 8-bit immediate value.
		temp_array[Rd], temp_array.CPSR = utility.CMP(registers[Rd], Offset8, CPSR)
		return_string[1] = return_string[1].."CMP"..end_string
		return_string[2] = "CMP     r"..Rd..", #"..Offset8
	elseif OP == 2 then
	--Add 8-bit immediate value to contents of Rd and place the result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.ADD(registers[Rd], Offset8, CPSR)
		return_string[1] = return_string[1].."ADD"..end_string
		return_string[2] = "ADD     r"..Rd..", #"..Offset8
	elseif OP == 3 then
	--Subtract 8-bit immediate value from contents of Rd and place the result in Rd.
		temp_array[Rd], temp_array.CPSR = utility.SUB(registers[Rd],Offset8, CPSR)
		return_string[1] = return_string[1].."SUB"..end_string
		return_string[2] = "SUB     r"..Rd..", #"..Offset8
	else
		return_string[1] = "Format 3 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format4(OP, Rs, Rd, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 4: ALU operations: ", ""}
	local end_string = " Rd, Rs\nRd: "..Rd.." ("..hex(registers[Rd])..") Rs: "..Rs.." ("..hex(registers[Rs])..")"
	if OP == 0  then
	--Rd:= Rd AND Rs
		temp_array[Rd], temp_array.CPSR = utility.AND(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."AND"..end_string
		return_string[2] = "AND     r"..Rd..", r"..Rs
	elseif OP == 1  then
	--Rd:= Rd EOR Rs
		temp_array[Rd], temp_array.CPSR = utility.EOR(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."EOR"..end_string
		return_string[2] = "EOR     r"..Rd..", r"..Rs
	elseif OP == 2  then
	--Rd := Rd << Rs
		temp_array[Rd], temp_array.CPSR = utility.LSL(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."LSL"..end_string
		return_string[2] = "LSL     r"..Rd..", r"..Rs
	elseif OP == 3  then
	--Rd := Rd >> Rs
		temp_array[Rd], temp_array.CPSR = utility.LSR2(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."LSR"..end_string
		return_string[2] = "LSR     r"..Rd..", r"..Rs
	elseif OP == 4  then
	--Rd := Rd ASR Rs
		temp_array[Rd], temp_array.CPSR = utility.ASR2(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."ASR"..end_string
		return_string[2] = "ASR     r"..Rd..", r"..Rs
	elseif OP == 5  then
	--Rd := Rd + Rs + C-bit
		temp_array[Rd], temp_array.CPSR = utility.ADC(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."ADC"..end_string
		return_string[2] = "ADC     r"..Rd..", r"..Rs
	elseif OP == 6  then
	--Rd := Rd - Rs - NOT C-bit
		temp_array[Rd], temp_array.CPSR = utility.SBC(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."SBC"..end_string
		return_string[2] = "SBC     r"..Rd..", r"..Rs
	elseif OP == 7  then
	--Rd := Rd ROR Rs
		temp_array[Rd], temp_array.CPSR = utility.ROR(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."ROR"..end_string
		return_string[2] = "ROR     r"..Rd..", r"..Rs
	elseif OP == 8  then
	--Set condition codes on Rd AND R
		temp_array[Rd], temp_array.CPSR = utility.TST(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."TST"..end_string
		return_string[2] = "TST     r"..Rd..", r"..Rs
	elseif OP == 9  then
	--Rd = 0-Rs
		temp_array[Rd], temp_array.CPSR = utility.NEG(registers[Rs], CPSR)
		return_string[1] = return_string[1].."NEG"..end_string
		return_string[2] = "NEG     r"..Rd..", r"..Rs
	elseif OP == 10  then
	--Set condition codes on Rd - Rs
		temp_array[Rd], temp_array.CPSR = utility.CMP(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."CMP"..end_string
		return_string[2] = "CMP     r"..Rd..", r"..Rs
	elseif OP == 11  then
	--Set condition codes on Rd + Rs
		temp_array[Rd], temp_array.CPSR = utility.CMN(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."CMN"..end_string
		return_string[2] = "CMN     r"..Rd..", r"..Rs
	elseif OP == 12  then
	--Rd := Rd OR Rs
		temp_array[Rd] = utility.ORR(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."ORR"..end_string
		return_string[2] = "ORR     r"..Rd..", r"..Rs
	elseif OP == 13 then
	--Rd := Rs * Rd
		temp_array[Rd] = utility.MUL(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."MUL"..end_string
		return_string[2] = "MUL     r"..Rd..", r"..Rs
	elseif OP == 14  then
	--Rd := Rd AND NOT Rs
		temp_array[Rd], temp_array = utility.BIC(registers[Rd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."BIC"..end_string
		return_string[2] = "BIC     r"..Rd..", r"..Rs
	elseif OP == 15  then
	--Rd := NOT Rs
		temp_array[Rd] = utility.MVN(_, registers[Rs], CPSR)
		return_string[1] = return_string[1].."MVN"..end_string
		return_string[2] = "MVN     r"..Rd..", r"..Rs
	else
		return_string[1] = "Format 4 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

local hi_reg_string = {[8] = "r8", [9] = "r9", [10] = "r10", [11] = "r11", [12] = "r12", [13] = "SP", [14] = "LR", [15] = "PC"}
function thumb_format5(OP, H1, H2, Rs, Rd, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local Hd = bit.lshift(H1, 3) + Rd
	local Hs = bit.lshift(H2, 3) + Rs
	--Combine OP and H1/H2 to avoid nested ifs for OP + H1 =? H2
	OP = bit.lshift(OP, 2) + bit.lshift(H1, 1) + H2
	local return_string = {"Format 5: Hi register operations/branch exchange: ", ""}
	local end_string = " Rd, Hs\nRd: "..Rd.." ("..hex(registers[Rd])..") Hs: "..Hs.." ("..hex(registers[Hs])..")"
	local end_string2 = " Hd, Rs\nRd: "..Hd.." ("..hex(registers[Hd])..") Rs: "..Rs.." ("..hex(registers[Rs])..")"
	local end_string3 = " Hd, Hs\nRd: "..Hd.." ("..hex(registers[Hd])..") Hs: "..Hs.." ("..hex(registers[Hs])..")"
	if OP == 0 then
		return_string[1] = "Format 5 error 1"	--undefined
		return_string[2] = return_string[1]
	elseif OP == 1 then
	--Add a register in the range 8-15 to a register in the range 0-7.
		temp_array[Rd], temp_array.CPSR = utility.ADD(registers[Rd], registers[Hs], temp_array.CPSR)
		return_string[1] = return_string[1].."ADD"..end_string
		return_string[2] = "ADD     r"..Rd..", "..hi_reg_string[Hs]
	elseif OP == 2 then
	--Add a register in the range 0-7 to a register in the range 8-15.
	--Don't set condition codes on R15/PC!
		if (Hd == 15) then
			temp_array[Hd], _ = utility.ADD(registers[Hd], registers[Rs], temp_array.CPSR)
		else
			temp_array[Hd], temp_array.CPSR = utility.ADD(registers[Hd], registers[Rs], temp_array.CPSR)
		end
		return_string[1] = return_string[1].."ADD"..end_string2
		return_string[2] = "ADD     "..hi_reg_string[Hd]..", r"..Rs
	elseif OP == 3 then
	--Add two registers in the range 8-15
		temp_array[Hd], temp_array.CPSR = utility.ADD(registers[Hd], registers[Hs], temp_array.CPSR)
		return_string[1] = return_string[1].."ADD"..end_string3
		return_string[2] = "ADD     "..hi_reg_string[Hd]..", "..hi_reg_string[Hs]
	elseif OP == 4 then
		return_string[1] = "Format 5 error 2"	--undefined
	elseif OP == 5 then
	--Compare a register in the range 0-7 with a register in the range 8-15.
		temp_array[Rd], temp_array.CPSR = utility.CMP(registers[Rd], registers[Hs], CPSR)
		return_string[1] = return_string[1].."CMP"..end_string
		return_string[2] = "CMP     r"..Rd..", "..hi_reg_string[Hs]
	elseif OP == 6 then
	--Compare a register in the range 8-15 with a register in the range 0-7.
		temp_array[Hd], temp_array.CPSR = utility.CMP(registers[Hd], registers[Rs], CPSR)
		return_string[1] = return_string[1].."CMP"..end_string2
		return_string[2] = "CMP     "..hi_reg_string[Hd]..", r"..Rs
	elseif OP == 7 then
	-- Compare two registers in the range 8-15.
		temp_array[Hd], temp_array.CPSR = utility.CMP(registers[Hd], registers[Hs], CPSR)
		return_string[1] = return_string[1].."CMP"..end_string3
		return_string[2] = "CMP     "..hi_reg_string[Hd]..", "..hi_reg_string[Hs]
	elseif OP == 8 then
		return_string[1] = "Format 5 error 3"	--undefined
		return_string[2] = return_string[1]
	elseif OP == 9 then
	--Move a value from a register in the range 8-15 to a register in the range 0-7.
		temp_array[Rd], temp_array.CPSR = utility.MOV(_, registers[Hs], CPSR)
		return_string[1] = return_string[1].."MOV"..end_string
		return_string[2] = "MOV     r"..Rd..", "..hi_reg_string[Hs]
	elseif OP == 10 then
	--Move a value from a register in the range 0-7 to a register in the range 8-15.
		temp_array[Hd], temp_array.CPSR = utility.MOV(_, registers[Rs], CPSR)
		return_string[1] = return_string[1].."MOV"..end_string2
		return_string[2] = "MOV     "..hi_reg_string[Hd]..", r"..Rs
	elseif OP == 11 then
	--Move a value between two registers in the range 8-15.
		temp_array[Hd], temp_array.CPSR = utility.MOV(_, registers[Hs], CPSR)
		return_string[1] = return_string[1].."MOV"..end_string3
		return_string[2] = "MOV     "..hi_reg_string[Hd]..", "..hi_reg_string[Hs]
	elseif OP == 12 then
	--Perform branch (plus optional state change) to address in a register in the range 0-7.
		temp_array[15], temp_array.CPSR = BX(registers[Rs], CPSR)
		return_string[1] = return_string[1].." BX Rs\nRs: "..Rs.." ("..hex(registers[Rs])..")"
		return_string[2] = "BX      r"..Rs
	elseif OP == 13 then
	--Perform branch (plus optional state change) to address in a register in the range 8-15.
		temp_array[15], temp_array.CPSR = BX(registers[Hs], CPSR)
		return_string[1] = return_string[1].."BX Hs\nHs: "..Hs.." ("..hex(registers[Hs])..")"
		return_string[2] = "BX      "..hi_reg_string[Hs]
	else
		return_string[1] = "Format 5 error 4"	--14, 15 are undefined
		return_string[2] = return_string[1]
	end
	temp_array[15] = bit.band(0xFFFFFFFE,temp_array[15])	--set last bit to 0 for register 15 in case it gets set by MOV
	return temp_array, return_string
end

function thumb_format6(Rd, Word8, registers)
	local temp_array = registers
	--Add unsigned offset (255 words, 1020 bytes) in Imm to the current value of the PC. 
	--Load the word from the resulting address into Rd
	local this = bit.check(registers[15],1) and 4 or 0	--Add 4 or 0 depending on ARM/THUMB mode
	local offset = Word8 * 4	--Word8 * 4 since Imm is shifted to the right by 2
	-- console.log("location :"..hex(bit.band(registers[15],0xFFFFFFFC) + this + (Word8 * 4)))
	temp_array[Rd] = utility.LDR(bit.band(registers[15],0xFFFFFFFC)+this, offset)	
	local return_string = {"Format 6: PC-relative load: LDR (load the value from PC + offset to Rd): LDR Rd, [PC, #Imm]\nRd: "..Rd.." PC: "..hex(registers[15]).." Imm: "..Word8, ""}
	return_string[2] = "LDR     r"..Rd..", [PC, #"..offset.."]"
	return temp_array, return_string
end

function thumb_format7(L, B, Ro, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 7: load/store with register offset: ", ""}
	local end_string = " Rd, [Rb, Ro]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.."("..hex(registers[Rb])..") Ro: "..Ro.."("..hex(registers[Ro])..")"
	local OP = (L * 2) + B	--Left shift L once, then add B to combine them
	local base = registers[Rb]
	local offset = registers[Ro]
	local value = registers[Rd]
	
	local end_string2 = offset == 0 and "]" or ", r"..Ro.."]"	--Probably should make a better name
	
	if OP == 0 then
	--Pre-indexed word store: Calculate the target address by adding together the value in Rb and the value in Ro. Store the contents of Rd at the address.
		if definition ~= true then utility.STR(base, offset, value) end
		return_string[1] = return_string[1].."STR"..end_string
		return_string[2] = "STR     r"..Rd..", [r"..Rb..end_string2
	elseif OP == 1 then
	--Pre-indexed byte store: Calculate the target address by adding together the value in Rb and the value in Ro. Store the byte value in Rd at the resulting address.
		if definition ~= true then utility.STRB(base, offset, value) end
		return_string[1] = return_string[1].."STRB"..end_string
		return_string[2] = "STRB    r"..Rd..", [r"..Rb..end_string2
	elseif OP == 2 then
	--Pre-indexed word load: Calculate the source address by adding together the value in Rb and the value in Ro. Load the contents of the address into Rd.
		temp_array[Rd] = utility.LDR(base, offset)
		return_string[1] = return_string[1].."LDR"..end_string
		return_string[2] = "LDR     r"..Rd..", [r"..Rb..end_string2
	elseif OP == 3 then
	--Pre-indexed byte load: Calculate the source address by adding together the value in Rb and the value in Ro. Load the byte value at the resulting address.
		temp_array[Rd] = utility.LDRB(base, offset)
		return_string[1] = return_string[1].."LDRB"..end_string
		return_string[2] = "LDRB    r"..Rd..", [r"..Rb..end_string2
	else	--If for some reason you placed 4 or higher
		return_string[1] = "Format 7 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format8(H, S, Ro, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 8: load/store sign-extended byte/halfword: ", ""}
	local end_string = " Rd, [Rb, Ro]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.."("..hex(registers[Rb])..") Ro: "..Ro.."("..hex(registers[Ro])..")"
	
	local OP = (H * 2) + S	--Left shift H once, then add S to combine them
	local base = registers[Rb]
	local offset = registers[Ro]
	local value = registers[Rd]
	
	local end_string2 = offset == 0 and "]" or ", #"..offset.."]"	--Probably should make a better name
	
	if OP == 0 then
	--Store halfword: Add Ro to base address in Rb. Store bits 0-15 of Rd at the resulting address.
		if definition ~= true then utility.STRH(base, offset, value) end
		return_string[1] = return_string[1].."STRH"..end_string
		return_string[2] = "STRH    r"..Rd..", [r"..Rb..end_string2
	elseif OP == 1 then
	--Load sign-extended byte: Add Ro to base address in Rb. Load bits 0-7 of Rd from the resulting address, and set bits 8-31 of Rd to bit 7.
		temp_array[Rd] = utility.LDRSB(base, offset)
		return_string[1] = return_string[1].."LDRSB"..end_string
		return_string[2] = "LDRSB   r"..Rd..", [r"..Rb..end_string2
	elseif OP == 2 then
	--Load halfword: Add Ro to base address in Rb. Load bits 0-15 of Rd from the resulting address, and set bits 16-31 of Rd to 0.
		temp_array[Rd] = utility.LDRH(base, offset)
		return_string[1] = return_string[1].."LDRH"..end_string
		return_string[2] = "LDRH    r"..Rd..", [r"..Rb..end_string2
	elseif OP == 3 then
	-- Load sign-extended halfword: Add Ro to base address in Rb. Load bits 0-15 of Rd from the resulting address, and set bits 16-31 of Rd to bit 15.
		temp_array[Rd] = utility.LDRSH(base, offset)
		return_string[1] = return_string[1].."LDRSH"..end_string
		return_string[2] = "LDRSH   r"..Rd..", [r"..Rb..end_string2
	else
		return_string[1] = "Format 8 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format9(B, L, Offset5, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local OP = (B * 2) + L	--Left shift B once, then add L to combine them
	local return_string = {"Format 9: load/store with immediate offset: ", ""}
	local end_string = " Rd, [Rb, #Imm]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.." ("..hex(registers[Rb])..") Imm: "..Offset5
	local base = registers[Rb]
	local offset = B == 0 and Offset5 * 4 or Offset5	--Shift this to the left by 2 if B == 0 (word access)
	local value = registers[Rd]
	
	local end_string2 = offset == 0 and "]" or ", #"..offset.."]"	--Probably should make a better name
	
	
	if OP == 0 then
	--Calculate the target address by adding together the value in Rb and Imm. Store the contents of Rd at the address.
		if definition ~= true then utility.STR(base, offset, value) end
		return_string[1] = return_string[1].."STR"..end_string
		return_string[2] = "STR     r"..Rd..", [r"..Rb..end_string2
	elseif OP == 1 then
	--Calculate the source address by adding together the value in Rb and Imm. Load Rd from the address.
		temp_array[Rd] = utility.LDR(base, offset)
		return_string[1] = return_string[1].."LDR"..end_string
		return_string[2] = "LDR     r"..Rd..", [r"..Rb..end_string2
	elseif OP == 2 then
	--Calculate the target address by adding together the value in Rb and Imm. Store the byte value in Rd at the address.
		if definition ~= true then utility.STRB(base, offset, value) end
		return_string[1] = return_string[1].."STRB"..end_string
		return_string[2] = "STRB    r"..Rd..", [r"..Rb..end_string2
	elseif OP == 3 then
	--Calculate source address by adding together the value in Rb and Imm. Load the byte value at the address into Rd.
		temp_array[Rd] = utility.LDRB(base, offset)
		return_string[1] = return_string[1].."LDRB"..end_string
		return_string[2] = "LDRB    r"..Rd..", [r"..Rb..end_string2
	else
		return_string[1] = "Format 9 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format10(L, Offset5, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 10: load/store halfword: ", ""}
	local end_string = " Rd, [Rb, #Imm]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.." ("..hex(registers[Rb])..") Imm: "..Offset5
	--Format 10 shifts offset5 left by 1
	--Doing this here so as to reuse the LDR/STR functions above
	local base = registers[Rb]
	local offset = Offset5 * 2
	local value = registers[Rd]
	
	local end_string2 = offset == 0 and "]" or ", #"..offset.."]"	--Probably should make a better name
	
	if L == 0 then 
	--Format 10: load/store halfword
	--Add #Imm to base address in Rb and store bits 0-15 of Rd at the resulting address.
		if definition ~= true then utility.STRH(base, offset, value) end
		return_string[1] = return_string[1].."STRH"..end_string
		return_string[2] = "STRH    r"..Rd..", [r"..Rb..end_string2
	elseif L == 1 then
	--Add #Imm to base address in Rb. Load bits 0-15 from the resulting address into Rd and set bits 16-31 to zero.
		temp_array[Rd] = utility.LDRH(base, offset)
		return_string[1] = return_string[1].."LDRH"..end_string
		return_string[2] = "LDRH    r"..Rd..", [r"..Rb..end_string2
	else	--If for some reason you placed 2 or higher
		return_string[1] = "Format 10 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format11(L, Rd, Word8, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = {"Format 11: SP-relative load/store: ", ""}
	local end_string = " Rd, [SP, #Imm]\nRd: "..Rd.." ("..hex(registers[Rd])..") SP: ("..hex(registers[7])..") Imm: "..Word8
	--Format 11 shifts Word8 left by 2
	local base = registers[13]
	local offset = Word8 * 4
	local value = registers[Rd]
	
	local end_string2 = offset == 0 and "]" or ", #"..offset.."]"	--Probably should make a better name
	
	if L == 0 then	
		--Add unsigned offset (255 words, 1020 bytes) in Imm to the current value of the SP (R7). Store the contents of Rd at the resulting address.
		if definition ~= true then utility.STR(base, offset, value) end
		return_string[1] = return_string[1].."STR"..end_string
		return_string[2] = "STR     r"..Rd..", [SP"..end_string2
	elseif L == 1 then
		--Add unsigned offset (255 words, 1020 bytes) in Imm to the current value of the SP (R7). Load the word from the resulting address into Rd.
		temp_array[Rd] = utility.LDR(base, offset)
		return_string[1] = return_string[1].."LDR"..end_string
		return_string[2] = "LDR     r"..Rd..", [SP"..end_string2
	else	--If for some reason you placed 2 or higher
		return_string[1] = "Format 11 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format12(SP, Rd, Word8, registers)
	local temp_array = registers
	local return_string = {"Format 12: load address: ", ""}
	Word8 = Word8 * 4
	local end_string = " Rd, PC, #Imm\nRd: "..Rd.." ("..hex(registers[Rd])..") PC: ("..hex(registers[15])..") Imm: "..Word8
	local end_string2 = " Rd, SP, #Imm\nRd: "..Rd.." ("..hex(registers[Rd])..") SP: ("..hex(registers[7])..") Imm: "..Word8
	--Don't set condition codes!
	if SP == 0 then
		temp_array[Rd], _ = utility.ADD(registers[15], Word8, temp_array.CPSR)
		return_string[1] = return_string[1].."ADD"..end_string
		return_string[2] = "ADD     r"..Rd..", PC, #"..Word8
	elseif SP == 1 then
		temp_array[Rd], _ = utility.ADD(registers[7], Word8, temp_array.CPSR)
		return_string[1] = return_string[1].."ADD"..end_string2
		return_string[2] = "ADD     r"..Rd..", SP, #"..Word8
	else
		return_string[1] = "Format 12 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format13(S, SWord7, registers)
	local temp_array = registers
	--Don't set condition codes!
	local return_string = {"Format 13: add offset to Stack Pointer: ", ""}
	SWord7 = SWord7 * 4	-- Shift left by 2 bits to get a 8 bit constant + sign
	if S == 0 then
		temp_array[13], _ = utility.ADD(registers[13], SWord7, temp_array.CPSR)
		return_string[1] = return_string[1].."ADD SP, #Imm\nSP: ("..hex(registers[13])..")"
		-- return_string[2] = "ADD     SP, #"..SWord7	--How manual displays it
		return_string[2] = "ADD     SP, SP, #"..SWord7	--How VBA-next trace log shows it
	elseif S == 1 then
		temp_array[13], _ = utility.SUB(registers[13], SWord7, temp_array.CPSR)
		return_string[1] = return_string[1].."ADD SP, #-Imm\nSP: ("..hex(registers[13])..")"
		-- return_string[2] = "ADD     SP, #-"..SWord7
		return_string[2] = "SUB     SP, SP #"..SWord7
	else
		return_string[1] = "Format 13 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format14(L, R, RList, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local return_string = {"Format 14: push/pop registers: ", ""}
	local OP = (L * 2) + R	--Left shift L once, then add R to combine them
	local end_string = "\nBase: ("..hex(registers[13])..")"	--Register 13 is Link Register
	local end_string2 = (L == 0) and ", LR}" or ", PC}"
	--Find out which registers are in RList
	local temp_list = {} 
	for i = 0, 7 do
		if bit.check(RList, i) then
			temp_list[#temp_list+1] = i
		end
	end
	
	local reg_string = "{"..utility.consec_number(temp_list)
	reg_string = (R == 1) and reg_string..end_string2 or reg_string.."}"
	end_string = end_string.." Registers: "..reg_string

	if OP == 0 then
		if definition ~= true then temp_array = PUSH(R, 13, RList, registers) end
		return_string[1] = return_string[1].."PUSH (push registers to stack)"..end_string
		return_string[2] = "PUSH    "..reg_string
	elseif OP == 1 then
		if definition ~= true then temp_array = PUSH(R, 13, RList, registers) end
		return_string[1] = return_string[1].."PUSH (push registers + link register to stack)"..end_string
		return_string[2] = "PUSH    "..reg_string
	elseif OP == 2 then
		temp_array = POP(R, 13, RList, registers)
		return_string[1] = return_string[1].."POP (pop values in stack off to registers)"..end_string
		return_string[2] = "POP    "..reg_string
	elseif OP == 3 then
		temp_array = POP(R, 13, RList, registers)
		return_string[1] = return_string[1].."POP (pop values in stack off to registers + program counter)"..end_string
		return_string[2] = "POP    "..reg_string
	else
		return_string[1] = "Format 14 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format15(L, Rb, RList, registers, definition)
	local temp_array = registers
	local return_string = {"Format 15: multiple load/store: ", ""}
	local end_string = "\nBase: "..Rb.." ("..hex(registers[Rb])..")"
	--Find out which registers are in RList
	local temp_list = {} 
	for i = 0, 7 do
		if bit.check(RList, i) then
			temp_list[#temp_list+1] = i
		end
	end
	
	local reg_string = "{"..utility.consec_number(temp_list).."}"
	
	if L == 0 then
		temp_array = PUSH(0, Rb, RList, registers)
		return_string[1] = return_string[1].."STMIA"..end_string
		return_string[2] = "STMIA   r"..Rb.."!, "..reg_string
	elseif L == 1 then --bit11 is 1
		temp_array = POP(0, Rb, RList, registers)
		return_string[1] = return_string[1].."LDMIA"..end_string
		return_string[2] = "LDMIA   r"..Rb.."!, "..reg_string
	else
		return_string[1] = "Format 15 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end

function thumb_format16(cond, Soffset8, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local orig = registers[15]	--need to do this since it changes.
	local result = Soffset8 * 2
	if bit.check(result, 8) then 
		result = result + 0x600	--set bits 9, 10 to 1
	end
	local dest = utility.B1(Soffset8, registers[15])
	local branch = false
	local return_string = {"Format 16: conditional branch: ", ""}
	--Copied from B1()
	if bit.check(result, 8) then	--Check 8th bit
		result = bit.bor(-256,result)	--writing as 0xFFFF FFFF FFFF FE00 doesn't work
		--result = bit.bor(0xFFFFF000,result)	--This works too
		result = result - 0x100000000	--??
	end
	if cond == 0 then
	--Branch if Z set (equal)
		branch = bit.check(CPSR, 30)
		return_string[1] = return_string[1].."BEQ (branch if z == 1)"
		return_string[2] = "BEQ     #+"..result
	elseif cond ==  1 then
	--Branch if Z clear (not equal)
		branch = bit.check(CPSR, 30) == false
		return_string[1] = return_string[1].."BNE (branch if z == 0)"
		return_string[2] = "BNE     #+"..result
	elseif cond == 2 then
	--Branch if C set (unsigned higher or same)
		branch = bit.check(CPSR, 29)
		return_string[1] = return_string[1].."BCS (branch if c == 1)"
		return_string[2] = "BCS     #+"..result
	elseif cond == 3 then
	--Branch if C clear (unsigned lower)
		branch = bit.check(CPSR, 29) == false
		return_string[1] = return_string[1].."BCC (branch if c == 0)"
		return_string[2] = "BCC     #+"..result
	elseif cond == 4 then
	--Branch if N set (negative)
		branch = bit.check(CPSR, 31)
		return_string[1] = return_string[1].."BMI (branch if n == 1)"
		return_string[2] = "BMI     #+"..result
	elseif cond == 5 then
	--Branch if N clear (positive or zero)
		branch = bit.check(CPSR, 31) == false
		return_string[1] = return_string[1].."BPL (branch if n == 0)"
		return_string[2] = "BPL     #+"..result
	elseif cond == 6 then
	--Branch if V set (overflow)
		branch = bit.check(CPSR, 28)
		return_string[1] = return_string[1].."BVS (branch if v == 1)"
		return_string[2] = "BVS     #+"..result
	elseif cond == 7 then
	--Branch if V clear (no overflow)
		branch = bit.check(CPSR, 28) == false
		return_string[1] = return_string[1].."BVC (branch if v == 0)"
		return_string[2] = "BVC     #+"..result
	elseif cond == 8 then
	--Branch if C set and Z clear (unsigned higher)
		branch = bit.check(CPSR, 29) and bit.check(CPSR, 30) == false
		return_string[1] = return_string[1].."BHI (branch if c == 1 and z == 0)"
		return_string[2] = "BHI     #+"..result
	elseif cond == 9 then
	--Branch if C clear or Z set (unsigned lower or same)
		branch = bit.check(CPSR, 29) == false or bit.check(CPSR, 30)
		return_string[1] = return_string[1].."BLS (branch if c == 0 or z == 1)"
		return_string[2] = "BLS     #+"..result
	elseif cond == 10 then
	--Branch if N set and V set, or N clear and V clear (greater or equal)
		branch = bit.check(CPSR, 28) == bit.check(CPSR, 31)
		return_string[1] = return_string[1].."BGE (branch if n == v)"
		return_string[2] = "BGE     #+"..result
	elseif cond == 11 then
	--Branch if N set and V clear, or N clear and V set (less than)
		branch = bit.check(CPSR, 28) ~= bit.check(CPSR, 31)
		return_string[1] = return_string[1].."BLT (branch if n != v)"
		return_string[2] = "BLT     #+"..result
	elseif cond == 12 then
	--Branch if Z clear, and either N set and V set or N clear and V clear (greater than)
		branch = bit.check(CPSR, 30) == false and (bit.check(CPSR, 28) == bit.check(CPSR, 31))
		return_string[1] = return_string[1].."BGT (branch if z == 0 and n == v)"
		return_string[2] = "BGT     #+"..result
	elseif cond == 13 then
	-- Branch if Z set, or N set and V clear, or N clear and V set (less than or equal)
		branch = bit.check(CPSR, 30) or (bit.check(CPSR, 28) ~= bit.check(CPSR, 31))
		return_string[1] = return_string[1].."BLE (branch if z == 1 or n != v)"
		return_string[2] = "BLE     #+"..result
	else
		return_string[1] = "Format 16 error"
		return_string[2] = return_string[1]
	end
	
	temp_array[15] = branch and dest or orig	--Branch
	-- Output what the 2 possible branching addresses
	return_string[1] = return_string[1].."\nTrue: 0x "..hex(dest + 2).." False: 0x " ..hex(orig + 2)
	return temp_array, return_string
end

function thumb_format17(Value8, registers)
	--todo
	local temp_array = registers
	local return_string = "Format 17:  software interrupt: "
	return temp_array, return_string
end

function thumb_format18(Offset11, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local dest = utility.B2(Offset11, temp_array[15], CPSR)
	temp_array[15] = dest
	--Copied from B()
	local result = Offset11 * 2
	if bit.check(result, 11) then
		result = bit.bor(-4096,result)	--writing as 0xFFFF FFFF FFFF F000 doesn't work
		--result = bit.bor(0xFFFFF000,result)	--This works too
		result = result - 0x100000000	--??
	end
	local return_string = {"Format 18: unconditional branch: Uncond. Jump\nOffset: 0x"..hex(Offset11), ""}
	return_string[1] = return_string[1].."\nBranch to: 0x "..hex(dest+2)
	return_string[2] = "B       #+"..result
	return temp_array, return_string
end

function thumb_format19(H, Offset, registers)
	local temp_array = registers
	local return_string = {"Format 19: long branch with link: ", ""}
	temp_array[14], temp_array[15] = BL(Offset, registers[14], registers[15], H)
	if H == 0 then
		return_string[1] = return_string[1].."Jump + LR := PC + OffsetHigh << 12"
		return_string[2] = "BL      0x"..("%08X"):format(temp_array[15])
	elseif H == 1 then --bit 11 is 1
		return_string[1] = return_string[1].."Jump + temp := next instruction address; PC := LR + OffsetLow << 1; LR := temp | 1"
		return_string[2] = "BL2     0x"..("%08X"):format(temp_array[15])
	else
		return_string[1] = "Format 19 error"
		return_string[2] = return_string[1]
	end
	return temp_array, return_string
end


function asm_thumb_module.do_instr(instruction, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	--https://ece.uwaterloo.ca/~ece222/ARM/ARM7-TDMI-manual-pt3.pdf
	--Thumb instruction set
	--for format 5:  Hi register operations/branch exchange
	local bit7 = bit.check(instruction,7) and 1 or 0
	local bit10 = bit.check(instruction,10) and 1 or 0
	local bit11 = bit.check(instruction,11) and 1 or 0
	local bit12 = bit.check(instruction,12) and 1 or 0
	local OP = bit.rshift(bit.band(0x1800,instruction),11)	--binary 0001 1000 0000 0000
	--We'll also treat Rs as Rb in the pdf
	local Rs = bit.rshift(bit.band(0x38,instruction),3)	--0x38 is 111000 in binary, and it to get only bits 3,4,5, then right shift them to obtain rs
	--Rd appears in 2 different locations in the pdf. We'll use Rd1 as the one for bits 0,1,2
	--and Rd2 for the one for bits 8, 9, 10 in format 11, 12
	local Rd = bit.band(0x7,instruction)	--binary 111
	local Rd2 = bit.rshift(bit.band(0x700,instruction), 8)	--binary 111 0000 0000
	local Rb1 = Rs	--Format 7, 8, 9, 10
	--Rn/Offset3, Ro correspond to the same bits
	local Ro = bit.rshift(bit.band(0x1C0,instruction),6)	--bits 6,7,8; binary 1 1100 0000
	local Offset5 = bit.rshift(bit.band(0x7C0,instruction),6) --bits 6,7,8,9,10; binary 111 1100 0000
	--Used in formats 3, 6, 11, 12, 14, 15, 16, 17
	local Offset8 = bit.band(0xFF,instruction)	--binary 0111 1111
	local Offset11 = bit.band(0x7FF,instruction)	--binary 0111 1111 1111
	
	local temp_array = {}
	local return_string = ""
	--Cannot use ternary operator trick "cond and a or b" to return 2 values sadly
	local format_num = asm_thumb_module.get_format(instruction)
	
	if format_num == 0 then 
		return_string = "Undef"
	elseif format_num == 1 then	--Format 1: move shifted register
		temp_array, return_string = thumb_format1(OP, Rd, Rs, Offset5, registers)
		
	elseif format_num == 2 then	--Format 2: add/subtract
		local bit_10_9 = bit.rshift(bit.band(0x600,instruction),9)	--binary 0110 0000 0000
		temp_array, return_string = thumb_format2(bit_10_9, Rd, Rs, Ro, registers)
		
	elseif format_num == 3 then	--Format 3: move/compare/add/subtract immediate
		temp_array, return_string = thumb_format3(OP, Rd2, Offset8, registers)
		
	elseif format_num == 4 then	--Format 4
		local bit_9_8_7_6 = bit.rshift(bit.band(0x3C0,instruction),6)	--binary 0011 1100 0000
		temp_array, return_string = thumb_format4(bit_9_8_7_6, Rs, Rd, registers)
		
	elseif format_num == 5 then	--Format 5
		local bit_9_8 = bit.rshift(bit.band(0x300,instruction),8)	--binary 0011 0000 0000
		local h2 = bit.check(instruction,6) and 1 or 0
		temp_array, return_string = thumb_format5(bit_9_8, bit7, h2, Rs, Rd, registers)
		
	elseif format_num == 6 then	--Format 6: PC-relative load
		temp_array, return_string = thumb_format6(Rd2, Offset8, registers)
		
	elseif format_num == 7 then	--Format 7: load/store with register offset
		temp_array, return_string = thumb_format7(bit11, bit10, Ro, Rb1, Rd, registers, definition)
		
	elseif format_num == 8 then	--Format 8: load/store sign-extended byte/halfword
		temp_array, return_string = thumb_format8(bit11, bit10, Ro, Rb1, Rd, registers, definition)
		
	elseif format_num == 9 then	-- Format 9: load/store with immediate offset
		temp_array, return_string = thumb_format9(bit12, bit11, Offset5, Rb1, Rd, registers, definition)
		
	elseif format_num == 10 then--Format 10: load/store halfword
		temp_array, return_string = thumb_format10(bit11, Offset5, Rb1, Rd, registers, definition)
	
	elseif format_num == 11 then--Format 11: SP-relative load/store
		temp_array, return_string = thumb_format11(bit11, Rd2, Offset8, registers, definition)
		
	elseif format_num == 12 then--Format 12: load address
		temp_array, return_string = thumb_format12(bit11, Rd2, Offset8, registers)
		
	elseif format_num == 13 then--Format 13: add offset to Stack Pointer
		local SWord7 = bit.band(0x7F,instruction)	--binary 0011 1111
		temp_array, return_string = thumb_format13(bit7, SWord7, registers)
			
	elseif format_num == 14 then--Format 14: push/pop registers
		local bit8 = bit.check(instruction,8) and 1 or 0
		temp_array, return_string = thumb_format14(bit11, bit8, Offset8, registers, definition)
		
	elseif format_num == 15 then--Format 15: multiple load/store
		temp_array, return_string = thumb_format15(bit11, Rd2, Offset8, registers, definition)
		
	elseif format_num == 16 then--Format 16: conditional branch
		local bit_11_10_9_8 = bit.rshift(bit.band(0xF00,instruction),8)	--binary 1111 0000 0000
		temp_array, return_string = thumb_format16(bit_11_10_9_8, Offset8, registers)
		
	elseif format_num == 17 then--Format 17: software interrupt
		temp_array, return_string = thumb_format17(Offset8, registers)
		
	elseif format_num == 18 then--Format 18: unconditional branch
		temp_array, return_string = thumb_format18(Offset11, registers)
		
	elseif format_num == 19 then--Format 19: long branch with link
		temp_array, return_string = thumb_format19(bit11, Offset11, registers)
	end
	
	temp_array[15] = temp_array[15] + 2
	return temp_array, return_string
end

function asm_thumb_module.get_thumb_instr(instruction, registers)
	local temp_array = {}
	local return_string = ""
	temp_array, return_string = asm_thumb_module.do_instr(instruction, registers, true)
	return return_string
end
--[[
Try checking bits 15-11, then branch from there.
15	14	13	12	11				4 bit number
0	0	0	0	0	Format 1	0
0	0	0	0	1	Format 1	1
0	0	0	1	0	Format 1	2
0	0	0	1	1	Format 2	3
0	0	1	0	0	Format 3	4
0	0	1	0	1	Format 3	5
0	0	1	1	0	Format 3	6
0	0	1	1	1	Format 3	7
0	1	0	0	0	Format 4	8 	(bit 10 = 0)
0	1	0	0	0	Format 5	8 	(bit 10 = 1)
0	1	0	0	1	Format 6	9
0	1	0	1	0	Format 7	10	(bit 9 = 0)
0	1	0	1	0	Format 8	10	(bit 9 = 1)
0	1	0	1	1	Format 7	11	(bit 9 = 0)
0	1	0	1	1	Format 8	11	(bit 9 = 1)
0	1	1	0	0	Format 9	12
0	1	1	0	1	Format 9	13
0	1	1	1	0	Format 9	14
0	1	1	1	1	Format 9	15
1	0	0	0	0	Format 10	16
1	0	0	0	1	Format 10	17
1	0	0	1	0	Format 11	18
1	0	0	1	1	Format 11	19
1	0	1	0	0	Format 12	20
1	0	1	0	1	Format 12	21
1	0	1	1	0	Format 13	22 (bit 10 = 0)
1	0	1	1	0	Format 14	22 (bit 10 = 1)
1	0	1	1	1	Format 14	23
1	1	0	0	0	Format 15	24
1	1	0	0	1	Format 15	25
1	1	0	1	0	Format 16	26
1	1	0	1	1	Format 16	27
1	1	0	1	1	Format 17	27	(bit 11,10,9,8 = 0b1111)
1	1	1	0	0	Format 18	28
1	1	1	0	1	Undef		29
1	1	1	1	0	Format 19	30
1	1	1	1	1	Format 19	31
]]--
function asm_thumb_module.get_format(instruction)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	--https://ece.uwaterloo.ca/~ece222/ARM/ARM7-TDMI-manual-pt3.pdf
	--Thumb instruction set
	local bit9 = bit.check(instruction, 9)
	local bit10 = bit.check(instruction, 10)
	local bit11_10_9_8 = bit.rshift(bit.band(0xF00, instruction), 8)			--binary 0000 1111 0000 0000
	local bit_15_14_13_12_11 = bit.rshift(bit.band(0xF800,instruction), 11)	--binary 1111 1000 0000 0000

	if bit_15_14_13_12_11 == 0 then return 1 end	-- 0	0	0	0	0	Format 1	0
	if bit_15_14_13_12_11 == 1 then return 1 end	-- 0	0	0	0	1	Format 1	1
	if bit_15_14_13_12_11 == 2 then return 1 end	-- 0	0	0	1	0	Format 1	2
	
	if bit_15_14_13_12_11 == 3 then return 2 end	-- 0	0	0	1	1	Format 2	3
	
	if bit_15_14_13_12_11 == 4 then return 3 end	-- 0	0	1	0	0	Format 3	4
	if bit_15_14_13_12_11 == 5 then return 3 end	-- 0	0	1	0	1	Format 3	5
	if bit_15_14_13_12_11 == 6 then return 3 end	-- 0	0	1	1	0	Format 3	6
	if bit_15_14_13_12_11 == 7 then return 3 end	-- 0	0	1	1	1	Format 3	7
	-- 0	1	0	0	0	Format 4	8 	(bit 10 = 0)
	-- 0	1	0	0	0	Format 5	8 	(bit 10 = 1)
	if bit_15_14_13_12_11 == 8 then return bit10 and 5 or 4 end
	
	if bit_15_14_13_12_11 == 9 then return 6 end	-- 0	1	0	0	1	Format 6	9
	-- 0	1	0	1	0	Format 7	10	(bit 9 = 0)
	-- 0	1	0	1	0	Format 8	10	(bit 9 = 1)
	if bit_15_14_13_12_11 == 10 then return bit9 and 8 or 7 end
	-- 0	1	0	1	1	Format 7	11	(bit 9 = 0)
	-- 0	1	0	1	1	Format 8	11	(bit 9 = 1)
	if bit_15_14_13_12_11 == 11 then return bit9 and 8 or 7 end
	
	if bit_15_14_13_12_11 == 12 then return 9 end	-- 0	1	1	0	0	Format 9	12
	if bit_15_14_13_12_11 == 13 then return 9 end	-- 0	1	1	0	1	Format 9	13
	if bit_15_14_13_12_11 == 14 then return 9 end	-- 0	1	1	1	0	Format 9	14
	if bit_15_14_13_12_11 == 15 then return 9 end	-- 0	1	1	1	1	Format 9	15
	
	if bit_15_14_13_12_11 == 16 then return 10 end	-- 1	0	0	0	0	Format 10	16
	if bit_15_14_13_12_11 == 17 then return 10 end	-- 1	0	0	0	1	Format 10	17
	
	if bit_15_14_13_12_11 == 18 then return 11 end	-- 1	0	0	1	0	Format 11	18
	if bit_15_14_13_12_11 == 19 then return 11 end	-- 1	0	0	1	1	Format 11	19


	if bit_15_14_13_12_11 == 20 then return 12 end	-- 1	0	1	0	0	Format 12	20
	if bit_15_14_13_12_11 == 21 then return 12 end	-- 1	0	1	0	1	Format 12	21
	-- 1	0	1	1	0	Format 13	22 (bit 10 = 0)
	-- 1	0	1	1	0	Format 14	22 (bit 10 = 1)
	if bit_15_14_13_12_11 == 22 then return bit10 and 14 or 13 end
	
	if bit_15_14_13_12_11 == 23 then return 14 end	-- 1	0	1	1	1	Format 14	23
	
	if bit_15_14_13_12_11 == 24 then return 15 end	-- 1	1	0	0	0	Format 15	24
	if bit_15_14_13_12_11 == 25 then return 15 end	-- 1	1	0	0	1	Format 15	25
	
	if bit_15_14_13_12_11 == 26 then return 16 end	-- 1	1	0	1	0	Format 16	26
	-- 1	1	0	1	1	Format 16	27
	-- 1	1	0	1	1	Format 17	27	(bit 11,10,9,8 = 0b1111)
	if bit_15_14_13_12_11 == 27 then return bit11_10_9_8 == 0xF and 17 or 16 end

	if bit_15_14_13_12_11 == 28 then return 18 end	-- 1	1	1	0	0	Format 18	28

	if bit_15_14_13_12_11 == 29 then return 0 end -- 1	1	1	0	1	Undef		29

	if bit_15_14_13_12_11 == 30 then return 19 end	-- 1	1	1	1	0	Format 19	30
	if bit_15_14_13_12_11 == 31 then return 19 end	-- 1	1	1	1	1	Format 19	31
end

return asm_thumb_module
