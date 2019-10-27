local utility = {}

function utility.set_flag(CPSR, N, Z, C, V, Q)
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
function utility.load_biz_addr(addr, size)
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

function utility.write_biz_addr(addr, value, size)
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

--ARM Manual A5-9, A5-10, A7-64, A7-66 (THUMB)
function utility.LSL(Rs, Offset, CPSR)
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
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-11, A7-68 (THUMB)
function utility.LSR1(Rs, Offset, CPSR)
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
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-12, A7-70 (THUMB)
function utility.LSR2(Rd, Rs, CPSR)
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
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-13, A7-15 (THUMB)
function utility.ASR1(Rm, Offset, CPSR)
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
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-14, A7-17 (THUMB)
function utility.ASR2(Rd, Rs, CPSR)
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
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end


--ARM Manual pA7-92
function utility.ROR(Rd, Rs, CPSR)
	--THUMB version
	--Rotate by the least significant byte (bits 7 to 0).
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 rotate
		result = Rd
	else
		--Apparently we now only care about bits 4 to 0 for the else
		Rs = bit.band(0xF, Rs)
		if Rs == 0 then 
			C = bit.check(Rd, 31) and 1 or 0
			result = Rd
		else	--Rs[4:0] > 0
			C = bit.check(Rd, Rs-1) and 1 or 0
			result = bit.ror(Rd, Rs)
		end
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-15, A5-17 (RRX)
function utility.ROR1(Rm, Offset, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 0, so in this case, it's either immediate offset of 5 bits, or register offset using the least significant byte. 
	--Bit 4 is 0, so it's immediate offset of 5 bits
	--"If R15 is specified as register Rm or Rn, the value used is the address of the current instruction plus 8"
	local result = nil
	local C = nil
	if Offset == 0 then
		--implement RRX
		--shifter_operand = (C Flag Logical_Shift_Left 31) OR (Rm Logical_Shift_Right 1)
		--shifter_carry_out = Rm[0]
		--[[If I understand correctly:
		1. Get bit 0 of Rm
		2. Logical shift right of Rm by 1
		3. Place 1) into bit 31 of result 2)
		]]--
		local temp = Rm % 2 --This is same as check first bit. Probably
		result = bit.lshift(Rm, 1)
		result = temp == 1 and bit.set(result, 31) or result
	else
		result = bit.ror(Rs, Offset)
		C = bit.check(Rm, Offset-1) and 1 or 0
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-16
function utility.ROR2(Rm, Rs, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 0, so in this case, it's either immediate offset of 5 bits, or register offset using the least significant byte. 
	--Bit 4 is 1, so it's register offset using the least significant byte. 
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	--"Specifying R15 as register Rd, register Rm, register Rn, or register Rs has UNPREDICTABLE results."
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		result = Rm
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 rotate
	else
		Rs = bit.band(0x1F, Rs) --Only care about first 5 bits
		if Rs == 0 then
			result = Rm
			C = bit.check(Rm, 31) and 1 or 0	--Differnt than above
		else	--Bits 0-4 are not 0
			result = bit.ror(Rm, Rs)
			C = bit.check(Rm, Rs-1) and 1 or 0
		end
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual pA5-6
function utility.ROR3(immed_8, rotate_imm, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 1, so in this case, it's immediate offset of 8 bits. 
	--Bits 11-8 are the amount to rotate, and bits 7-0 are the immediate offset
	--"If R15 is specified as register Rn, the value used is the address of the current instruction plus eight"
	--The above line should be done BEFORE you give ROR3 the numbers in a different function
	local result = nil
	local C = nil
	if rotate_imm == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 rotate
	else
		result = bit.ror(immed_8, rotate_imm*2)
		C = bit.check(result, 31) and 1 or 0	--Set this to bit 31 of the shifted number instead of the original
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

return utility
