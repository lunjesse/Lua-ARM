local hex = bizstring.hex
local asm_thumb_module = {}


function set_flag(CPSR, N, Z, C, V, Q)
	--CPSR is status register
	--Usage: set_flag(r,1,1,1,1) example
	--[[https://nintenfo.github.io/repository/webmirrors/techinfo.html
	Bit   Expl.
  31    N - Sign Flag       (0=Not Signed, 1=Signed)               ;\
  30    Z - Zero Flag       (0=Not Zero, 1=Zero)                   ; Condition
  29    C - Carry Flag      (0=Borrow/No Carry, 1=Carry/No Borrow) ; Code Flags
  28    V - Overflow Flag   (0=No Overflow, 1=Overflow)            ;/
  27    Q - Sticky Overflow (1=Sticky Overflow, ARMv5TE and up only)
  26-8  Reserved            (For future use) - Do not change manually!
  7     I - IRQ disable     (0=Enable, 1=Disable)                     ;\
  6     F - FIQ disable     (0=Enable, 1=Disable)                     ; Control
  5     T - State Bit       (0=ARM, 1=THUMB) - Do not change manually!; Bits
  4-0   M4-M0 - Mode Bits   (See below)                               ;/
	]]--
	local temp = CPSR
	-- console.log("Now: "..bizstring.binary(temp))
	if N > 0 then temp = bit.set(temp,31) else temp = bit.clear(temp,31) end
	if Z > 0 then temp = bit.set(temp,30) else temp = bit.clear(temp,30) end
	if C > 0 then temp = bit.set(temp,29) else temp = bit.clear(temp,29) end
	if V > 0 then temp = bit.set(temp,28) else temp = bit.clear(temp,28) end
	if Q > 0 then temp = bit.set(temp,27) else temp = bit.clear(temp,27) end
	-- console.log("N: "..N.." Z: "..Z.." C: "..C.." V: "..V.." Q: "..Q)
	-- console.log("After: "..bizstring.binary(temp))
	return temp
end

--since bizhawk hates the 0x8/0x3/0x4 part, remove it
function load_biz_addr(addr, size)
	local destination
	local read_memory = memory.read_u32_le	--default
	if size == 8 then
		read_memory = memory.read_u8
	elseif size == 16 then
		read_memory = memory.read_u16_le
	elseif size == 24 then
		read_memory = memory.read_u24_le
	end
	if addr < 0x01000000 and addr > 0x00000000 then
		destination = read_memory(addr, "BIOS")
	elseif addr < 0x03000000 and addr > 0x02000000 then
		destination = read_memory(addr - 0x02000000,"EWRAM")
	elseif addr < 0x04000000 and addr > 0x03000000 then
		destination = read_memory(addr - 0x03000000,"IWRAM")
	elseif addr < 0x05000000 and addr > 0x04000000 then
		destination = read_memory(addr - 0x04000000,"System Bus")
	elseif addr < 0x09000000 and addr > 0x08000000 then
		destination = read_memory(addr - 0x08000000,"ROM")
	end
	return destination
end

function write_biz_addr(addr, value, size)
	local write_memory = memory.write_u32_le	--default
	if size == 8 then
		write_memory = memory.write_u8
	elseif size == 16 then
		write_memory = memory.write_u16_le
	elseif size == 24 then
		write_memory = memory.write_u24_le
	end
	if addr < 0x01000000 and addr > 0x00000000 then
		-- dont touch BIOS
		-- write_memory(addr, value, "BIOS")
	elseif addr < 0x03000000 and addr > 0x02000000 then
		write_memory(addr - 0x02000000, value, "EWRAM")
	elseif addr < 0x04000000 and addr > 0x03000000 then
		write_memory(addr - 0x03000000, value, "IWRAM")
	elseif addr < 0x05000000 and addr > 0x04000000 then
		write_memory(addr - 0x04000000, value, "System Bus")
	elseif addr < 0x09000000 and addr > 0x08000000 then
		--dont write in ROM
		-- write_memory(addr - 0x08000000, value, "ROM")
	end
end

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
	return load_biz_addr(address,size)
end

function LSL(Rs, Offset, CPSR)
--Imagine that the shift happens with a double-wide register, and then at the end we cut off the lower 32 bits to get the new value, and then the next bit onward is the carry flag
--diagram https://www.csee.umbc.edu/courses/undergraduate/313/spring04/burt_katz/lectures/Lect06/shift.html
	--There are 2 cases. LSL immediate offset of 5 bits, and LSL register offset using the least significant byte (bits 7 to 0). 
	--We first mask the Offset into an 8 bit number; this won't change anything if it was the 5 bit offset
	Offset = bit.band(0xFF, Offset)
	local result = nil
	local C = nil
	--LSL immediate
	if Offset == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 shift
		result = Rs
	elseif Offset < 32 then 
		C = bit.check(Rs, 32-Offset) and 1 or 0
		result = bit.lshift(Rs, Offset)
	--LSL register
	elseif Offset == 32 then
		C = bit.check(Rs, 0) and 1 or 0
		result = 0
	else	--Greater than 32
		C = 0
		result = 0
	end
	local N = bit.check(result, 31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function LSR1(Rs, Offset, CPSR)
	--There are 2 cases. LSR immediate offset of 5 bits, and LSR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's immediate offset. An offset of 0 indicates logical right shift of 32 rather than 0; 
	--instead, LSR #0 is converted to LSL #0. This applies to ASR and ROR as well
	local result = nil
	local C = nil
	if Offset == 0 then
		C = bit.check(Rs, 31) and 1 or 0
		result = 0
	else
		C = bit.check(Rs, Offset-1) and 1 or 0
		result = bit.rshift(Rs, Offset)
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function LSR2(Rd, Rs, CPSR)
	--There are 2 cases. LSR immediate offset of 5 bits, and LSR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's register offset. Unlike LSR1, this does allow LSR #0 to occur.
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 shift
		result = Rd
	elseif Rs < 32 then
		C = bit.check(Rd, Rs-1) and 1 or 0
		result = bit.rshift(Rd, Rs)
	elseif Rs == 32 then
		C = bit.check(Rd, 31) and 1 or 0
		result = 0
	else	--Greater than 32
		C = 0
		result = 0
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function ASR1(Rm, Offset, CPSR)
	--There are 2 cases. ASR immediate offset of 5 bits, and ASR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's immediate offset. An offset of 0 indicates arithmetic right shift of 32 rather than 0; 
	--instead, ASR #0 is converted to LSL #0. This applies to LSR and ROR as well
	local result = nil
	local C = nil
	if Offset == 0 then
		C = bit.check(Rm, 31) and 1 or 0
		if C == 0 then
			result = 0
		else	--bit 31 of Rm is 1
			result = 0xFFFFFFFF
		end
	else
		C = bit.check(Rm, Offset-1) and 1 or 0
		result = bit.arshift(Rs, Offset)
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function ASR2(Rd, Rs, CPSR)
	--There are 2 cases. ASR immediate offset of 5 bits, and ASR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's register offset. Unlike ASR1, this does allow ASR #0 to occur.
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 shift
		result = Rd
	elseif Rs < 32 then
		C = bit.check(Rd, Rs-1) and 1 or 0
		result = bit.arshift(Rs, Rs)
	else --Greater than 32
		C = bit.check(Rd, 31) and 1 or 0
		if C == 0 then
			result = 0
		else	--bit 31 of Rd is 1
			result = 0xFFFFFFFF
		end
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function ADC(Rs, Rn, Carry, CPSR)
	--we need carry as well, since some instructions ignore carry flag
	local N_L = bit.check(CPSR, 31) and 1 or 0
	local Z_L = bit.check(CPSR, 30) and 1 or 0
	local C_L = bit.check(CPSR, 29) and 1 or 0
	local V_L = bit.check(CPSR, 28) and 1 or 0
	local Q_L = bit.check(CPSR, 27) and 1 or 0
	-- console.log("Before: N: "..N_L.." Z: "..Z_L.." C: "..C_L.." V: "..V_L.." Q: "..Q_L)
	-- console.log("RS: "..hex(Rs).." RN:"..hex(Rn).." Carry: "..Carry)
	local max32s = 2^32
	local sum = (Rs + Rn + Carry)
	local sum32 = sum % max32s
	-- console.log(hex(sum))
	-- console.log("Mod: "..hex(sum32))
	local N = bit.check(sum32,31) and 1 or 0
	local Z = (sum32 == 0) and 1 or 0
	--[[
	The carry flag is set if the addition of two numbers causes a carry
	out of the most significant (leftmost) bits added.
	Since lua is 64 bit while the registers are 32 bit, we can just check 
	if the result ended up smaller than mod 2,147,483,647‬
	]]--
	local C = (sum > 0xFFFFFFFF) and 1 or 0
	local V = 0
	--[[http://teaching.idallen.com/dat2343/10f/notes/040_overflow.txt
	In unsigned arithmetic, watch the carry flag to detect errors.
	In signed arithmetic, the carry flag tells you nothing interesting.
	]]--
	--[[
	1. If the sum of two numbers with the sign bits off yields a result number
   with the sign bit on, the "overflow" flag is turned on.
	2. If the sum of two numbers with the sign bits on yields a result number
   with the sign bit off, the "overflow" flag is turned on.
	Since lua is 64 bit while the registers are 32 bit, we can just check 
	if bit 31 was changed on addition
	]]--
	local Rs_sign = bit.check(Rs, 31) and 1 or 0
	local Rn_sign = bit.check(Rn, 31) and 1 or 0
	local sum32_sign = bit.check(sum32, 31) and 1 or 0
	-- console.log("Rs_sign: "..Rs_sign.." Rn_sign: "..Rn_sign.." Sum32_sign: "..sum32_sign)
	if Rn_sign == 0 then	--2nd operand positive
		V = (Rs_sign == Rn_sign and sum32_sign ~= Rs_sign) and 1 or 0
	else	--2nd operand negative
		V = (Rn_sign == sum32_sign and Rs_sign ~= Rn_sign) and 1 or 0
	end
	local Q = bit.check(CPSR, 27) and 1 or 0	--unchanged
	-- console.log("After: N: "..N.." Z: "..Z.." C: "..C.." V: "..V.." Q: "..Q)
	return sum32, set_flag(CPSR, N, Z, C, V, Q)
end

function ADD(Rs, Rn, CPSR)
	return ADC(Rs, Rn, 0, CPSR)
end

--In the case of adding to the program counter, do not set flags
function ADD2(Rs, Rn, CPSR)
	local temp = CPSR
	local result, flags = ADC(Rs, Rn, 0, temp)
	return result, CPSR	--dont change flags
end

function SBC(Rs, Rn, CPSR)
	local temp = CPSR
	local C = bit.check(CPSR, 29) and 1 or 0
	return ADC(Rs, bit.bnot(Rn), C, temp)
end

function SUB(Rs, Rn, CPSR)
	return ADC(Rs, bit.bnot(Rn), 1, CPSR)
end

--In the case of adding to the program counter, do not set flags
function SUB2(Rs, Rn, CPSR)
	return ADC(Rs, bit.bnot(Rn), 1, CPSR)
end


function MOV(Offset8, CPSR)
	local N = bit.check(Offset8,31) and 1 or 0
	local Z = (Offset8 == 0) and 1 or 0
	local C = bit.check(CPSR, 29) and 1 or 0	--not sure if changed
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return Offset8, set_flag(CPSR, N, Z, C, V, Q)
end

function AND(Rd, Rs, CPSR)
	local result = bit.band(Rd,Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function EOR(Rd, Rs, CPSR)
	local result = bit.bxor(Rd, Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function ROR(Rd, Rs, CPSR)
	local result = bit.ror(Rd, Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function NEG(Rs)
	return -1 * Rs
end

function ORR(Rd, Rs, CPSR)
	local result = bit.bor(Rd, Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function MUL(Rd, Rs, CPSR)
	local result = Rd * Rs;
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	local C = bit.check(CPSR, 29) and 1 or 0
	--C, V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function BIC(Rd, Rs, CPSR)
	local result = bit.band(Rd, bit.bnot(Rs))
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, set_flag(CPSR, N, Z, C, V, Q)
end

function MVN(Rs, CPSR)
	local N = bit.check(Rs,31) and 1 or 0
	local Z = (Rs == 0) and 1 or 0
	--Manual sets carry by LSL shift 0; this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0	
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return bit.bnot(Rs)
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


function LDR(Rb, Ro)
--don't set flags
	return load_biz_addr(Rb + Ro, 32)
end

function LDRB(Rb, Ro)
--don't set flags
	return load_biz_addr(Rb + Ro, 8)
end

function LDRH(Rb, Ro)
--Add Ro to base address in Rb. Load bits 0-15 of Rd from the resulting address, and set bits 16-31 of Rd to 0.
	local result = load_biz_addr(Rb + Ro, 32)
	result = bit.band(0xFFFF, result)	-- binary 1111 1111 1111 1111
	for i = 16, 31 do
		bit.clear(result,i)
	end
	return result
end

function LDSB(Rb, Ro)
--Add Ro to base address in Rb. Load bits 0-7 of Rd from the resulting address, and set bits 8-31 of Rd to bit 7.
	local result = load_biz_addr(Rb + Ro, 32)
	local bit7 = bit.check(result,7) and 1 or 0
	result = bit.band(0xFF, result)	-- binary 1111 1111
	for i = 8, 31 do
		bit.set(result,bit7)
	end
	return result
end

function LDSH(Rb, Ro)
--Add Ro to base address in Rb. Load bits 0-15 of Rd from the resulting address, and set bits 16-31 of Rd to bit 15.
	local result = load_biz_addr(Rb + Ro, 32)
	local bit15 = bit.check(result,15) and 1 or 0
	result = bit.band(0xFFFF, result)	-- binary 1111 1111 1111 1111
	for i = 16, 31 do
		bit.set(result,bit15)
	end
	return result
end

function STR(Rd, Rb, Ro)
	write_biz_addr(Rb + Ro, Rd, 32)
	return
end

function STRB(Rd, Rb, Ro)
	write_biz_addr(Rb + Ro, Rd, 8)
	return
end

function STRH(Rd, Rb, Ro)
	--Add Ro to base address in Rb. Store bits 0-15 of Rd at the resulting address
	local bit_0_15 = bit.band(0xFFFF, Rd)	-- binary 1111 1111 1111 1111
	write_biz_addr(Rb + Ro, bit_0_15, 32)
	return
end

function B(Offset11, r15)
	--don't set flags
	--Shifting the 11-bit signed offset of the instruction left one bit.
	--Sign-extending the result to 32 bits
	--Adding this to the contents of the PC (which contains the address of the branch instruction plus 4). 
	--Lua is 64 bit however
	local result = bit.lshift(Offset11, 1)
	if bit.check(result, 11) then
		result = bit.bor(-4096,result)	--writing as 0xFFFF FFFF FFFF F000 doesn't work
		--result = bit.bor(0xFFFFF000,result)	--This works too
		result = result - 0x100000000	--??
	end
	--technically you're supposed to jump by 4, and not increment PC again, but making this +2 with PC also +2 makes life easier
	return r15 + result + 2
end

function BL(offset,LR,PC,H_flag)
	--don't set flags
	--long branch with link
	for i = 11,15 do
		offset = bit.clear(offset,i)
	end
	if H_flag == 0 then
		return PC + bit.lshift(offset,12) + 2, PC
	else
		local temp = PC
		return bit.bor(temp,1), bit.lshift(offset,1) + LR
	end
end

--Format 16 Branch instructions
function BEQ(offset, r15, CPSR)
	--Branch if Z set (equal)
	-- local Z = bit.check(CPSR, 30) and 1 or 0
	if bit.check(CPSR, 30) then
		return B(offset, r15)
	else
		return r15
	end
end

function BNE(offset, r15, CPSR)
	--Branch if Z clear (not equal)
	-- local Z = bit.check(CPSR, 30) and 1 or 0
	if bit.check(CPSR, 30) == false then
		return B(offset, r15)
	else
		return r15
	end
end

function BCS(offset, r15, CPSR)
	--Branch if C set (unsigned higher or same)
	-- local C = bit.check(CPSR, 29) and 1 or 0
	if bit.check(CPSR, 29) then
		return B(offset, r15)
	else
		return r15
	end
end

function BCC(offset, r15, CPSR)
	--Branch if C clear (unsigned lower)
	-- local C = bit.check(CPSR, 29) and 1 or 0
	if bit.check(CPSR, 29) == false then
		return B(offset, r15)
	else
		return r15
	end
end

function BMI(offset, r15, CPSR)
	--Branch if N set (negative)
	-- local N = bit.check(CPSR, 31) and 1 or 0
	if bit.check(CPSR, 31) then
		return B(offset, r15)
	else
		return r15
	end
end

function BPL(offset, r15, CPSR)
	--Branch if N clear (positive or zero)
	-- local N = bit.check(CPSR, 31) and 1 or 0
	if bit.check(CPSR, 31) == false then
		return B(offset, r15)
	else
		return r15
	end
end

function BVS(offset, r15, CPSR)
	--Branch if V set (overflow)
	-- local V = bit.check(CPSR, 28) and 1 or 0
	if bit.check(CPSR, 28) then
		return B(offset, r15)
	else
		return r15
	end
end

function BVC(offset, r15, CPSR)
	--Branch if V clear (no overflow)
	-- local V = bit.check(CPSR, 28) and 1 or 0
	if bit.check(CPSR, 28) == false then
		return B(offset, r15)
	else
		return r15
	end
end

function BHI(offset, r15, CPSR)
	--Branch if C set and Z clear (unsigned higher)
	-- local C = bit.check(CPSR, 29) and 1 or 0
	-- local Z = bit.check(CPSR, 30) and 1 or 0
	if bit.check(CPSR, 29) and bit.check(CPSR, 30) == false then
		return B(offset, r15)
	else
		return r15
	end
end

function BLS(offset, r15, CPSR)
	--Branch if C clear or Z set (unsigned lower or same)
	-- local C = bit.check(CPSR, 29) and 1 or 0
	-- local Z = bit.check(CPSR, 30) and 1 or 0
	if bit.check(CPSR, 29) == false or bit.check(CPSR, 30) then
		return B(offset, r15)
	else
		return r15
	end
end

function BGE(offset, r15, CPSR)
	--Branch if N set and V set, or N clear and V clear (greater or equal)
	--So basically N == V
	-- local V = bit.check(CPSR, 28) and 1 or 0
	-- local N = bit.check(CPSR, 31) and 1 or 0
	if bit.check(CPSR, 28) == bit.check(CPSR, 31) then
		return B(offset, r15)
	else
		return r15
	end
end

function BLT(offset, r15, CPSR)
	--Branch if N set and V clear, or N clear and V set (less than)
	--So basically N ~= V
	-- local V = bit.check(CPSR, 28) and 1 or 0
	-- local N = bit.check(CPSR, 31) and 1 or 0
	if bit.check(CPSR, 28) ~= bit.check(CPSR, 31) then
		return B(offset, r15)
	else
		return r15
	end
end

function BGT(offset, r15, CPSR)
	--Branch if Z clear, and either N set and V set or N clear and V clear (greater than)
	-- local V = bit.check(CPSR, 28) and 1 or 0
	-- local Z = bit.check(CPSR, 30) and 1 or 0
	-- local N = bit.check(CPSR, 31) and 1 or 0
	if bit.check(CPSR, 30) == false and (bit.check(CPSR, 28) == bit.check(CPSR, 31)) then
		return B(offset, r15)
	else
		return r15
	end
end

function BLE(offset, r15, CPSR)
	-- Branch if Z set, or N set and V clear, or N clear and V set (less than or equal)
	-- local V = bit.check(CPSR, 28) and 1 or 0
	-- local Z = bit.check(CPSR, 30) and 1 or 0
	-- local N = bit.check(CPSR, 31) and 1 or 0
	if bit.check(CPSR, 30) or (bit.check(CPSR, 28) ~= bit.check(CPSR, 31)) then
		return B(offset, r15)
	else
		return r15
	end
end

function CMP(Rd, Rs, CPSR)
--From ARM manual: Compare (immediate) subtracts an immediate value from a register value. 
--It updates the condition flags based on the result, and discards the result.
--This is also used for format 5
	local _, CPSR2 = SUB(Rd, Rs, CPSR)
	return CPSR2
end

function CMN(Rd, Rs, CPSR)
--From ARM manual: Compare Negative (register) adds a register value and an optionally-shifted register value. 
--It updates the condition flags based on the result, and discards the result.
	local _, CPSR2 = ADD(Rd, Rs, CPSR)
	return CPSR2
end

function TST(Rd, Rs, CPSR)
--From  ARM manual: Test (register) performs a logical AND operation on a register value and an optionally-shifted register value.
--It updates the condition flags based on the result, and discards the result.
	local _, CPSR2 = AND(Rd, Rs, CPSR)
	return CPSR2
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
			write_biz_addr(addr, Registers[i], 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		write_biz_addr(addr, SP, 32)
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
			temp[i] = load_biz_addr(addr, 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		temp[15] = bit.band(0xFFFFFFFE, load_biz_addr(addr, 32))	--Mask away bit 0, since it's used to determine ARM/THUMB mode
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
			write_biz_addr(addr, registers[i], 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		write_biz_addr(addr, Ri, 32)
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
			temp_array[i] = load_biz_addr(addr, 32)
			addr = addr + 4
		end
	end
	if R == 1 then 
		temp_array[15] = bit.band(0xFFFFFFFE, load_biz_addr(addr, 32))	--Mask away bit 0, since it's used to determine ARM/THUMB mode
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
	local return_string = "Format 1: move shifted register: "
	local end_string = " Rd, Rs, #Offset5\nRd: "..Rd.." ("..hex(registers[Rd])..") Rs: "..Rs.." ("..hex(registers[Rs])..") Offset5: "..Offset5
	if OP == 0 then
	--Shift Rs left by a 5-bit immediate value and store the result in Rd.
		-- console.log(hex(temp_array[Rd]))
		temp_array[Rd], temp_array.CPSR = LSL(registers[Rs], Offset5, CPSR)
		return_string = return_string.."LSL"..end_string
	elseif OP == 1 then
	--Perform logical shift right on Rs by a 5-bit immediate value and store the result in Rd.
		temp_array[Rd], temp_array.CPSR = LSR1(registers[Rs], Offset5, CPSR)
		return_string = return_string.."LSR"..end_string
	elseif OP == 2 then
	--Perform arithmetic shift right on Rs by a 5-bit immediate value and store the result in Rd.
		temp_array[Rd], temp_array.CPSR = ASR(registers[Rs], Offset5, CPSR)
		return_string = return_string.."ASR"..end_string
	else
		return_string = "Format 1 error"
	end
	return temp_array, return_string
end

function thumb_format2(OP, Rd, Rs, Rn, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 2: add/subtract: "
	local end_string = " Rd, Rs, Rn\nRd: "..Rd.." ("..hex(registers[Rd])..") Rs: "..Rs.." ("..hex(registers[Rs])..")"
	local end_string2 = end_string.." Rn: "..Rn.." ("..hex(registers[Rn])..")"
	local end_string3 = end_string.." Offset3: "..Rn	--its 3 bits, no need to make it hex
	if OP == 0 then
--Add contents of Rn to contents of Rs. Place result in Rd
		temp_array[Rd], temp_array.CPSR = ADD(registers[Rs], registers[Rn], CPSR)
		return_string = return_string.."ADD"..end_string2
	elseif OP == 1 then
--Subtract contents of Rn from contents of Rs. Place result in Rd.
		temp_array[Rd], temp_array.CPSR = SUB(registers[Rs], registers[Rn], CPSR)
		return_string = return_string.."SUB"..end_string2
	elseif OP == 2 then
--Add 3-bit immediate value to contents of Rs. Place result in Rd.
		temp_array[Rd], temp_array.CPSR = ADD(registers[Rs], Offset3, CPSR)
		return_string = return_string.."ADD"..end_string3
	elseif OP == 3 then
--Subtract 3-bit immediate value from contents of Rs. Place result in Rd.
		temp_array[Rd], temp_array.CPSR = SUB(registers[Rs], Offset3, CPSR)
		return_string = return_string.."SUB"..end_string3
	else
		return_string = "Format 2 error"
	end
	return temp_array, return_string
end

function thumb_format3(OP, Rd, Offset8, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = " Format 3: move/compare/add/subtract immediate: "
	local end_string = " Rd, #Offset8\nRd: "..Rd.." ("..hex(registers[Rd])..") Offset8: "..Offset8
	if OP == 0 then
	--Move 8-bit immediate value into Rd.
		temp_array[Rd], temp_array.CPSR = MOV(Offset8, CPSR)
		return_string = return_string.."MOV"..end_string
	elseif OP == 1 then
	--Compare contents of Rd with 8-bit immediate value.
		temp_array.CPSR = CMP(registers[Rd], Offset8, CPSR)
		return_string = return_string.."CMP"..end_string
	elseif OP == 2 then
	--Add 8-bit immediate value to contents of Rd and place the result in Rd.
		temp_array[Rd], temp_array.CPSR = ADD(registers[Rd], Offset8, CPSR)
		return_string = return_string.."ADD"..end_string
	elseif OP == 3 then
	--Subtract 8-bit immediate value from contents of Rd and place the result in Rd.
		temp_array[Rd], temp_array.CPSR = SUB(registers[Rd],Offset8, CPSR)
		return_string = return_string.."SUB"..end_string
	else
		return_string = "Format 3 error"
	end
	return temp_array, return_string
end

function thumb_format4(OP, Rs, Rd, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 4: ALU operations: "
	local end_string = " Rd, Rs\nRd: "..Rd.." ("..hex(registers[Rd])..") Rs: "..Rs.." ("..hex(registers[Rs])..")"
	if OP == 0  then
	--Rd:= Rd AND Rs
		temp_array[Rd], temp_array.CPSR = AND(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."AND"..end_string
	elseif OP == 1  then
	--Rd:= Rd EOR Rs
		temp_array[Rd], temp_array.CPSR = EOR(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."EOR"..end_string
	elseif OP == 2  then
	--Rd := Rd << Rs
		temp_array[Rd], temp_array.CPSR = LSL(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."LSL"..end_string
	elseif OP == 3  then
	--Rd := Rd >> Rs
		temp_array[Rd], temp_array.CPSR = LSR2(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."LSR"..end_string
	elseif OP == 4  then
	--Rd := Rd ASR Rs
		temp_array[Rd], temp_array.CPSR = ASR(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."ASR"..end_string
	elseif OP == 5  then
	--Rd := Rd + Rs + C-bit
		temp_array[Rd], temp_array.CPSR = ADC(registers[Rd], registers[Rs], C, CPSR)
		return_string = return_string.."ADC"..end_string
	elseif OP == 6  then
	--Rd := Rd - Rs - NOT C-bit
		temp_array[Rd], temp_array.CPSR = SBC(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."SBC"..end_string
	elseif OP == 7  then
	--Rd := Rd ROR Rs
		temp_array[Rd], temp_array.CPSR = ROR(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."ROR"..end_string
	elseif OP == 8  then
	--Set condition codes on Rd AND R
		TST(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."TST"..end_string
	elseif OP == 9  then
	--Rd = -Rs
		temp_array[Rd] = NEG(registers[Rs])
		return_string = return_string.."NEG"..end_string
	elseif OP == 10  then
	--Set condition codes on Rd - Rs
		temp_array.CPSR = CMP(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."CMP"..end_string
	elseif OP == 11  then
	--Set condition codes on Rd + Rs
		temp_array.CPSR = CMN(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."CMN"..end_string
	elseif OP == 12  then
	--Rd := Rd OR Rs
		temp_array[Rd] = ORR(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."ORR"..end_string
	elseif OP == 13 then
	--Rd := Rs * Rd
		temp_array[Rd] = MUL(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."MUL"..end_string
	elseif OP == 14  then
	--Rd := Rd AND NOT Rs
		temp_array[Rd], temp_array = BIC(registers[Rd], registers[Rs], CPSR)
		return_string = return_string.."BIC"..end_string
	elseif OP == 15  then
	--Rd := NOT Rs
		temp_array[Rd] = MVN(registers[Rs], CPSR)
		return_string = return_string.."MVN"..end_string
	else
		return_string = "Format 4 error"
	end
	return temp_array, return_string
end

function thumb_format5(OP, H1, H2, Rs, Rd, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local Hd = bit.lshift(H1, 3) + Rd
	local Hs = bit.lshift(H2, 3) + Rs
	--Combine OP and H1/H2 to avoid nested ifs for OP + H1 =? H2
	OP = bit.lshift(OP, 2) + bit.lshift(H1, 1) + H2
	local return_string = "Format 5: Hi register operations/branch exchange: "
	local end_string = " Rd, Hs\nRd: "..Rd.." ("..hex(registers[Rd])..") Hs: "..Hs.." ("..hex(registers[Hs])..")"
	local end_string2 = " Hd, Rs\nRd: "..Hd.." ("..hex(registers[Hd])..") Rs: "..Rs.." ("..hex(registers[Rs])..")"
	local end_string3 = " Hd, Hs\nRd: "..Hd.." ("..hex(registers[Hd])..") Hs: "..Hs.." ("..hex(registers[Hs])..")"
	if OP == 0 then
		return_string = "Format 5 error 1"	--undefined
	elseif OP == 1 then
	--Add a register in the range 8-15 to a register in the range 0-7.
		temp_array[Rd], temp_array.CPSR = ADD(registers[Rd], registers[Hs], temp_array.CPSR)
		return_string = return_string.."ADD"..end_string
	elseif OP == 2 then
	--Add a register in the range 0-7 to a register in the range 8-15.
	--Don't set condition codes on R15/PC!
		if (Hd == 15) then
			temp_array[Hd], temp_array.CPSR = ADD2(registers[Hd], registers[Rs], temp_array.CPSR)
		else
			temp_array[Hd], temp_array.CPSR = ADD(registers[Hd], registers[Rs], temp_array.CPSR)
		end
		return_string = return_string.."ADD"..end_string2
	elseif OP == 3 then
	--Add two registers in the range 8-15
		temp_array[Hd], temp_array.CPSR = ADD(registers[Hd], registers[Hs], temp_array.CPSR)
		return_string = return_string.."ADD"..end_string3
	elseif OP == 4 then
		return_string = "Format 5 error 2"	--undefined
	elseif OP == 5 then
	--Compare a register in the range 0-7 with a register in the range 8-15.
		temp_array.CPSR = CMP(registers[Rd], registers[Hs], CPSR)
		return_string = return_string.."CMP"..end_string
	elseif OP == 6 then
	--Compare a register in the range 8-15 with a register in the range 0-7.
		temp_array.CPSR = CMP(registers[Hd], registers[Rs], CPSR)
		return_string = return_string.."CMP"..end_string2
	elseif OP == 7 then
	-- Compare two registers in the range 8-15.
		temp_array.CPSR = CMP(registers[Hd], registers[Hs], CPSR)
		return_string = return_string.."CMP"..end_string3
	elseif OP == 8 then
		return_string = "Format 5 error 3"	--undefined
	elseif OP == 9 then
	--Move a value from a register in the range 8-15 to a register in the range 0-7.
		temp_array[Rd], temp_array.CPSR = MOV(registers[Hs], CPSR)
		return_string = return_string.."MOV"..end_string
	elseif OP == 10 then
	--Move a value from a register in the range 0-7 to a register in the range 8-15.
		temp_array[Hd], temp_array.CPSR = MOV(registers[Rs], CPSR)
		return_string = return_string.."MOV"..end_string2
	elseif OP == 11 then
	--Move a value between two registers in the range 8-15.
		temp_array[Hd], temp_array.CPSR = MOV(registers[Hs], CPSR)
		return_string = return_string.."MOV"..end_string3
	elseif OP == 12 then
	--Perform branch (plus optional state change) to address in a register in the range 0-7.
		temp_array[15], temp_array.CPSR = BX(registers[Rs], CPSR)
		return_string = return_string.." BX Rs\nRs: "..Rs.." ("..hex(registers[Rs])..")"
	elseif OP == 13 then
	--Perform branch (plus optional state change) to address in a register in the range 8-15.
		temp_array[15], temp_array.CPSR = BX(registers[Hs], CPSR)
		return_string = return_string.."BX Hs\nHs: "..Hs.." ("..hex(registers[Hs])..")"
	else
		return_string = "Format 5 error 4"	--14, 15 are undefined
	end
	temp_array[15] = bit.band(0xFFFFFFFE,temp_array[15])	--set last bit to 0 for register 15 in case it gets set by MOV
	return temp_array, return_string
end

function thumb_format6(Rd, Word8, registers)
	local temp_array = registers
	--Add unsigned offset (255 words, 1020 bytes) in Imm to the current value of the PC. 
	--Load the word from the resulting address into Rd
	local this = bit.check(registers[15],1) and 4 or 0	--Add 4 or 0 depending on ARM/THUMB mode
	-- console.log("location :"..hex(bit.band(registers[15],0xFFFFFFFC) + this + (Word8 * 4)))
	temp_array[Rd] = LDR(bit.band(registers[15],0xFFFFFFFC)+this, Word8 * 4)	--Word8 * 4 since Imm is shifted to the right by 2
	local return_string = "Format 6: PC-relative load: LDR (load the value from PC + offset to Rd): LDR Rd, [PC, #Imm]\nRd: "..Rd.." PC: "..hex(registers[15]).." Imm: "..Word8
	return temp_array, return_string
end

function thumb_format7(L, B, Ro, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 7: load/store with register offset: "
	local end_string = " Rd, [Rb, Ro]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.."("..hex(registers[Rb])..") Ro: "..Ro.."("..hex(registers[Ro])..")"
	local OP = (L * 2) + B	--Left shift L once, then add B to combine them
	if OP == 0 then
	--Pre-indexed word store: Calculate the target address by adding together the value in Rb and the value in Ro. Store the contents of Rd at the address.
		if definition ~= true then STR(registers[Rd], registers[Rb], registers[Ro]) end
		return_string = return_string.."STR"..end_string
	elseif OP == 1 then
	--Pre-indexed byte store: Calculate the target address by adding together the value in Rb and the value in Ro. Store the byte value in Rd at the resulting address.
		if definition ~= true then STRB(registers[Rd], registers[Rb], registers[Ro]) end
		return_string = return_string.."STRB"..end_string
	elseif OP == 2 then
	--Pre-indexed word load: Calculate the source address by adding together the value in Rb and the value in Ro. Load the contents of the address into Rd.
		temp_array[Rd] = LDR(registers[Rb], registers[Ro])
		return_string = return_string.."LDR"..end_string
	elseif OP == 3 then
	--Pre-indexed byte load: Calculate the source address by adding together the value in Rb and the value in Ro. Load the byte value at the resulting address.
		temp_array[Rd] = LDRB(registers[Rb], registers[Ro])
		return_string = return_string.."LDRB"..end_string
	else	--If for some reason you placed 4 or higher
		return_string = "Format 7 error"
	end
	return temp_array, return_string
end

function thumb_format8(H, S, Ro, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 8: load/store sign-extended byte/halfword: "
	local end_string = " Rd, [Rb, Ro]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.."("..hex(registers[Rb])..") Ro: "..Ro.."("..hex(registers[Ro])..")"
	local OP = (H * 2) + S	--Left shift H once, then add S to combine them
	if OP == 0 then
	--Store halfword: Add Ro to base address in Rb. Store bits 0-15 of Rd at the resulting address.
		if definition ~= true then STRH(registers[Rd], registers[Rb], registers[Ro]) end
		return_string = return_string.."STRH"..end_string
	elseif OP == 1 then
	--Load sign-extended byte: Add Ro to base address in Rb. Load bits 0-7 of Rd from the resulting address, and set bits 8-31 of Rd to bit 7.
		temp_array[Rd] = LDSB(registers[Rb], registers[Ro])
		return_string = return_string.."LDSB"..end_string
	elseif OP == 2 then
	--Load halfword: Add Ro to base address in Rb. Load bits 0-15 of Rd from the resulting address, and set bits 16-31 of Rd to 0.
		temp_array[Rd] = LDRH(registers[Rb], registers[Ro])
		return_string = return_string.."LDRH"..end_string
	elseif OP == 3 then
	-- Load sign-extended halfword: Add Ro to base address in Rb. Load bits 0-15 of Rd from the resulting address, and set bits 16-31 of Rd to bit 15.
		temp_array[Rd] = LDSH(registers[Rb], registers[Ro])
		return_string = return_string.."LDSH"..end_string
	else
		return_string = "Format 8 error"
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
	local return_string = "Format 9: load/store with immediate offset: "
	local end_string = " Rd, [Rb, #Imm]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.." ("..hex(registers[Rb])..") Imm: "..Offset5
	Offset5 = B == 0 and Offset5 * 4 or Offset5	--Shift this to the left by 2 if B == 0 (word access)
	if OP == 0 then
	--Calculate the target address by adding together the value in Rb and Imm. Store the contents of Rd at the address.
		if definition ~= true then STR(registers[Rd], registers[Rb], Offset5) end
		return_string = return_string.."STR"..end_string
	elseif OP == 1 then
	--Calculate the source address by adding together the value in Rb and Imm. Load Rd from the address.
		temp_array[Rd] = LDR(registers[Rb], Offset5)
		return_string = return_string.."LDR"..end_string
	elseif OP == 2 then
	--Calculate the target address by adding together the value in Rb and Imm. Store the byte value in Rd at the address.
		if definition ~= true then STRB(registers[Rd], registers[Rb], Offset5) end
		return_string = return_string.."STRB"..end_string
	elseif OP == 3 then
	--Calculate source address by adding together the value in Rb and Imm. Load the byte value at the address into Rd.
		temp_array[Rd] = LDRB(registers[Rb], Offset5)
		return_string = return_string.."LDRB"..end_string
	else
		return_string = "Format 9 error"
	end
	return temp_array, return_string
end

function thumb_format10(L, Offset5, Rb, Rd, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 10: load/store halfword: "
	local end_string = " Rd, [Rb, #Imm]\nRd: "..Rd.." ("..hex(registers[Rd])..") Rb: "..Rb.." ("..hex(registers[Rb])..") Imm: "..Offset5
	--Format 10 shifts offset5 left by 1
	--Doing this here so as to reuse the LDR/STR functions above
	Offset5 = Offset5 * 2
	if L == 0 then 
	--Format 10: load/store halfword
	--Add #Imm to base address in Rb and store bits 0-15 of Rd at the resulting address.
		if definition ~= true then STRH(registers[Rd], registers[Rb], Offset5) end
		return_string = return_string.."STRH"..end_string
	elseif L == 1 then
	--Add #Imm to base address in Rb. Load bits 0-15 from the resulting address into Rd and set bits 16-31 to zero.
		temp_array[Rd] = LDRH(registers[Rb], Offset5)
		return_string = return_string.."LDRH"..end_string
	else	--If for some reason you placed 2 or higher
		return_string = "Format 10 error"
	end
	return temp_array, return_string
end

function thumb_format11(L, Rd, Word8, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 11: SP-relative load/store: "
	local end_string = " Rd, [SP, #Imm]\nRd: "..Rd.." ("..hex(registers[Rd])..") SP: ("..hex(registers[7])..") Imm: "..Word8
	--Format 11 shifts Word8 left by 2
	Word8 = Word8 * 4
	if L == 0 then	
		--Add unsigned offset (255 words, 1020 bytes) in Imm to the current value of the SP (R7). Store the contents of Rd at the resulting address.
		if definition ~= true then STR(registers[Rd], registers[7], Word8) end
		return_string = return_string.."STR"..end_string
	elseif L == 1 then
		--Add unsigned offset (255 words, 1020 bytes) in Imm to the current value of the SP (R7). Load the word from the resulting address into Rd.
		temp_array[Rd] = LDR(registers[7], Word8)
		return_string = return_string.."LDR"..end_string
	else	--If for some reason you placed 2 or higher
		return_string = "Format 11 error"
	end
	return temp_array, return_string
end

function thumb_format12(SP, Rd, Word8, registers)
	local temp_array = registers
	local return_string = "Format 12: load address: "
	local end_string = " Rd, PC, #Imm\nRd: "..Rd.." ("..hex(registers[Rd])..") PC: ("..hex(registers[15])..") Imm: "..Word8
	local end_string2 = " Rd, SP, #Imm\nRd: "..Rd.." ("..hex(registers[Rd])..") SP: ("..hex(registers[7])..") Imm: "..Word8
	--Don't set condition codes!
	if SP == 0 then
		temp_array[Rd], temp_array.CPSR = ADD2(registers[15], Word8, temp_array.CPSR)
		return_string = return_string.."ADD"..end_string
	elseif SP == 1 then
		temp_array[Rd], temp_array.CPSR = ADD2(registers[7], Word8, temp_array.CPSR)
		return_string = return_string.."ADD"..end_string2
	else
		return_string = "Format 12 error"
	end
	return temp_array, return_string
end

function thumb_format13(S, Sword7, registers)
	local temp_array = registers
	--Don't set condition codes!
	local return_string = "Format 13: add offset to Stack Pointer: "
	if S == 0 then
		temp_array[13], temp_array.CPSR = ADD2(registers[13], SWord7, temp_array.CPSR)
		return_string = return_string.."ADD SP, #Imm\nSP: ("..hex(registers[13])..")"
	elseif S == 1 then
		temp_array[13], temp_array.CPSR = SUB2(registers[13], SWord7, temp_array.CPSR)
		return_string = return_string.."ADD SP, #-Imm\nSP: ("..hex(registers[13])..")"
	else
		return_string = "Format 13 error"
	end
	return temp_array, return_string
end

function thumb_format14(L, R, RList, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	local temp_array = registers
	local return_string = "Format 14: push/pop registers: "
	local OP = (L * 2) + R	--Left shift L once, then add R to combine them
	local end_string = "\nBase: ("..hex(registers[13])..")"	--Register 13 is Link Register
	local end_string2 = (L == 0) and ", SP}" or ", PC}"
	--Setting the string here, so if definition is false, we can skip this
	if (definition == true) then
		end_string = end_string.." Registers: {"
		for i = 0, 7 do
		--its this, or ugly bit.check(RList, i)
			if i < 7 then 
				if bit.rshift(RList, i) % 2 == 1 then end_string = end_string..i..", " end
			else
				if bit.rshift(RList, i) % 2 == 1 then end_string = end_string..i end
			end
		end
		end_string = (R == 1) and end_string..end_string2 or end_string.."}"
	end
	if OP == 0 then
		if definition ~= true then temp_array = PUSH(R, 13, RList, registers) end
		return_string = return_string.."PUSH (push registers to stack)"..end_string
	elseif OP == 1 then
		if definition ~= true then temp_array = PUSH(R, 13, RList, registers) end
		return_string = return_string.."PUSH (push registers + link register to stack)"..end_string
	elseif OP == 2 then
		temp_array = POP(R, 13, RList, registers)
		return_string = return_string.."POP (pop values in stack off to registers)"..end_string
	elseif OP == 3 then
		temp_array = POP(R, 13, RList, registers)
		return_string = return_string.."POP (pop values in stack off to registers + program counter)"..end_string
	else
		return_string = "Format 14 error"
	end
	return temp_array, return_string
end

function thumb_format15(L, Rb, RList, registers, definition)
	local temp_array = registers
	local return_string = "Format 15: multiple load/store: "
	local end_string = "\nBase: "..Rb.." ("..hex(registers[Rb])..")"
	--Setting the string here, so if definition is false, we can skip this
	if (definition == true) then
		end_string = end_string.." Registers: {"
		for i = 0, 7 do
		--its this, or ugly bit.check(RList, i)
			if i < 7 then 
				if bit.rshift(RList, i) % 2 == 1 then end_string = end_string..i..", " end
			else
				if bit.rshift(RList, i) % 2 == 1 then end_string = end_string..i end
			end
		end
		end_string = end_string.."}"
	end
	if L == 0 then
		temp_array = PUSH(0, Rb, RList, registers)
		return_string = return_string.."STMIA"..end_string
	elseif L == 1 then --bit11 is 1
		temp_array = POP(0, Rb, RList, registers)
		return_string = return_string.."LDMIA"..end_string
	else
		return_string = "Format 15 error"
	end
	return temp_array, return_string
end

function thumb_format16(cond, Soffset8, registers)
	local temp_array = registers
	local CPSR = registers.CPSR
	local return_string = "Format 16: conditional branch: "
	if cond == 0 then
	--Branch if Z set (equal)
		temp_array[15] = BEQ(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BEQ (branch if z == 1)"
	elseif cond ==  1 then
	--Branch if Z clear (not equal)
		temp_array[15] = BNE(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BNE (branch if z == 0)"
	elseif cond == 2 then
	--Branch if C set (unsigned higher or same)
		temp_array[15] = BCS(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BCS (branch if c == 1)"
	elseif cond == 3 then
	--Branch if C clear (unsigned lower)
		temp_array[15] = BCC(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BCC (branch if c == 0)"
	elseif cond == 4 then
	--Branch if N set (negative)
		temp_array[15] = BMI(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BMI (branch if n == 1)"
	elseif cond == 5 then
	--Branch if N clear (positive or zero)
		temp_array[15] = BPL(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BPL (branch if n == 0)"
	elseif cond == 6 then
	--Branch if V set (overflow)
		temp_array[15] = BVS(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BVS (branch if v == 1)"
	elseif cond == 7 then
	--Branch if V clear (no overflow)
		temp_array[15] = BVC(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BVC (branch if v == 0)"
	elseif cond == 8 then
	--Branch if C set and Z clear (unsigned higher)
		temp_array[15] = BHI(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BHI (branch if c == 1 and z == 0)"
	elseif cond == 9 then
	--Branch if C clear or Z set (unsigned lower or same)
		temp_array[15] = BLS(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BLS (branch if c == 0 and z == 1)"
	elseif cond == 10 then
	--Branch if N set and V set, or N clear and V clear (greater or equal)
		temp_array[15] = BGE(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BGE (branch if n == v)"
	elseif cond == 11 then
	--Branch if N set and V clear, or N clear and V set (less than)
		temp_array[15] = BLT(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BLT (branch if n != v)"
	elseif cond == 12 then
	--Branch if Z clear, and either N set and V set or N clear and V clear (greater than)
		temp_array[15] = BGT(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BGT (branch if z == 0 and n == v)"
	elseif cond == 13 then
	-- Branch if Z set, or N set and V clear, or N clear and V set (less than or equal)
		temp_array[15] = BLE(Soffset8, temp_array[15], CPSR)
		return_string = return_string.."BLE (branch if z == 1 or n != v)"
	else
		return_string = "Format 16 error"
	end
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
	temp_array[15] = B(Offset11, temp_array[15])
	return_string = "Format 18: unconditional branch: Uncond. Jump\nOffset: "..Offset11
	return temp_array, return_string
end

function thumb_format19(H, Offset, registers)
	local temp_array = registers
	local return_string = "Format 19: long branch with link: "
	temp_array[14], temp_array[15] = BL(Offset, registers[14], registers[15], H)
	if H == 0 then
		return_string = return_string.."Jump + LR := PC + OffsetHigh << 12"
	elseif H == 1 then --bit 11 is 1
		return_string = return_string.."Jump + temp := next instruction address; PC := LR + OffsetLow << 1; LR := temp | 1"
	else
		return_string = "Format 19 error"
	end
	return temp_array, return_string
end


function asm_thumb_module.do_instr(instruction, registers, definition)
	--For all other formats, you can just fake it by ignore temp_array.
	--So we make a "definition" flag so that if its set, we dont write anything to memory
	--That way, we won't mess things up (probably)
	--https://ece.uwaterloo.ca/~ece222/ARM/ARM7-TDMI-manual-pt3.pdf
	--Thumb instruction set
	local bits_3 = bit.rshift(instruction,13)	--check the first 3 left bits
	--for format 5:  Hi register operations/branch exchange
	local bit7 = bit.check(instruction,7) and 1 or 0
	local bit10 = bit.check(instruction,10) and 1 or 0
	local bit11 = bit.check(instruction,11) and 1 or 0
	local bit12 = bit.check(instruction,12) and 1 or 0
	local bit_12_11 = bit.rshift(bit.band(0x1800,instruction),11)	--binary 0001 1000 0000 0000
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
	local temp_array = {}
	local return_string = ""
	-- local CPSR = registers.CPSR
	-- local C = bit.check(CPSR, 29) and 1 or 0
	--Cannot use ternary operator trick "cond and a or b" to return 2 values sadly
	if bits_3 == 0 then --bit pattern 000
	--Format 2 has bits 12 and 11 == 0b11 (3 in decimal). So if they're not 3, use format 1 instead
	--Format 1: move shifted register
	--Format 2: add/subtract
	-- local Rn = Ro
		local bit_10_9 = bit.rshift(bit.band(0x600,instruction),9)	--binary 0110 0000 0000
		if (bit_12_11 == 3) then 
			temp_array, return_string = thumb_format2(bit_10_9, Rd, Rs, Ro, registers)
		else
			temp_array, return_string = thumb_format1(bit_12_11, Rd, Rs, Offset5, registers)
		end
	elseif bits_3 == 1 then --bit pattern 001
	--Format 3
		temp_array, return_string = thumb_format3(bit_12_11, Rd2, Offset8, registers)
	elseif bits_3 == 2 then --bit pattern 010
	--Format 4
		local bit_12_11_10 = bit.rshift(bit.band(0x1C00,instruction),10)	--binary 0001 1100 0000 0000
		if bit_12_11_10 == 0 then
			local bit_9_8_7_6 = bit.rshift(bit.band(0x3C0,instruction),6)	--binary 0011 1100 0000
			temp_array, return_string = thumb_format4(bit_9_8_7_6, Rs, Rd, registers)
		elseif bit_12_11_10 == 1 then
		--Format 5
		--Don't set condition codes on R15/PC!
		--Hd/Hs are used nowhere else, so assign them herelocal h1 = bit7
			local bit_9_8 = bit.rshift(bit.band(0x300,instruction),8)	--binary 0011 0000 0000
			local h2 = bit.check(instruction,6) and 1 or 0
			temp_array, return_string = thumb_format5(bit_9_8, bit7, h2, Rs, Rd, registers)
		elseif bit_12_11_10 == 2 or bit_12_11_10 == 3 then	--binary 010
		--Format 6: PC-relative load
		--Don't increment PC here
		--Word8 == Offset8
			temp_array, return_string = thumb_format6(Rd2, Offset8, registers)
		elseif bit_12_11_10 >= 4 and bit_12_11_10 <= 7 then	--bit12 is 1
			--If bit 9 == 0, format 7. Else format 8
			--Format 7: load/store with register offset
			--Format 8: load/store sign-extended byte/halfword
			local bit9 = bit.check(instruction,9) and 1 or 0
			if (bit9 == 0) then
				temp_array, return_string = thumb_format7(bit11, bit10, Ro, Rb1, Rd, registers, definition)
			else
				temp_array, return_string = thumb_format8(bit11, bit10, Ro, Rb1, Rd, registers, definition)
			end
		end
	elseif bits_3 == 3 then --bit pattern 011
		-- Format 9: load/store with immediate offset
		temp_array, return_string = thumb_format9(bit12, bit11, Offset5, Rb1, Rd, registers, definition)
	elseif bits_3 == 4 then --bit pattern 100
		--Check bit 12 to see if we use format 10 or 11. 0 for format 10, 1 for format 11
		--Format 10: load/store halfword
		--Format 11: SP-relative load/store
		-- local Word8 = Offset8	--binary 0111 1111
		if (bit12 == 0) then
			temp_array, return_string = thumb_format10(bit11, Offset5, Rb1, Rd, registers, definition)
		else
			temp_array, return_string = thumb_format11(bit11, Rd2, Offset8, registers, definition)
		end	
	elseif bits_3 == 5 then --bit pattern 101
		if bit12 == 0 then
		--Format 12: load address
		-- local Word8 = Offset8	--binary 0111 1111
			temp_array, return_string = thumb_format12(bit11, Rd2, Offset8, registers)
		else --bit12 is 1 
		--Check bit 10 to see if we use format 13 or 14. 0 for format 13, 1 for format 14
		--Format 13: add offset to Stack Pointer
		--Format 14: push/pop registers
		-- local RList = Offset8	--binary 0111 1111
			local bit8 = bit.check(instruction,8) and 1 or 0
			local SWord7 = bit.band(0x7F,instruction)	--binary 0011 1111
			if (bit10 == 0 ) then
				temp_array, return_string = thumb_format13(bit7, Sword7, registers)
			else
				temp_array, return_string = thumb_format14(bit11, bit8, Offset8, registers, definition)
			end			
		end
	elseif bits_3 == 6 then --bit pattern 101
		if bit12 == 0 then
		--Format 15: multiple load/store
		-- local Rb2 = Rd2 bits 10_9_8
		-- local RList = Offset8	--binary 0111 1111
			temp_array, return_string = thumb_format15(bit11, Rd2, Offset8, registers, definition)
		else --bit12 is 1
		--Check if bits 11, 10, 9, 8 are all 1 (ie. cond == 15) to see if we use format 16 or 17. 15 for format 17, all else for format 16
		--Format 16: conditional branch
		--Format 17: software interrupt
		-- local Value8 = Offset8	--binary 0111 1111
		-- local Soffset8 = Offset8	--binary 0111 1111
			local bit_11_10_9_8 = bit.rshift(bit.band(0xF00,instruction),8)	--binary 1111 0000 0000
			if (bit_11_10_9_8 == 15) then
				temp_array, return_string = thumb_format17(Offset8, registers)
			else
				temp_array, return_string = thumb_format16(bit_11_10_9_8, Offset8, registers)
			end
		end
	elseif bits_3 == 7 then --bit pattern 111
		--Check bit 12 to see if we use format 18 or 19. 0 for format 18, 1 for format 19
		--Format 18: unconditional branch
		--Format 19: long branch with link
		local Offset11 = bit.band(0x7FF,instruction)	--binary 0111 1111 1111
		if (bit12 == 0) then
			temp_array, return_string = thumb_format18(Offset11, registers)
		else
			temp_array, return_string = thumb_format19(bit11, Offset11, registers)
		end
	else
		return_string = "Undef"
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
Try checking bits 15-12, then branch from there. 13 Outer branches
15	14	13	12				4 bit number
0	0	0	X	Format 1	0 or 1
0	0	0	1	Format 2	1
0	0	1	X	Format 3	2 or 3
0	1	0	0	Format 4	4
0	1	0	0	Format 5	4
0	1	0	0	Format 6	4
0	1	0	1	Format 7	5
0	1	0	1	Format 8	5
0	1	1	X	Format 9	6 or 7
1	0	0	0	Format 10	8
1	0	0	1	Format 11	9
1	0	1	0	Format 12	10
1	0	1	1	Format 13	11
1	0	1	1	Format 14	11
1	1	0	0	Format 15	12
1	1	0	1	Format 16	13
1	1	0	1	Format 17	13
1	1	1	0	Format 18	14
1	1	1	1	Format 19	15
]]--

return asm_thumb_module
