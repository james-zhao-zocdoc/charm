-- module ARM where

import qualified Data.ByteString as B

import Data.Binary
import Data.Binary.Get

import Data.Maybe
import Data.List
import Data.Int
import Data.Word
import Data.Bits

import Text.Printf

import Control.Monad

import Debug.Trace

data ARMArch = ARM_EXT_V1
             | ARM_EXT_V2
             | ARM_EXT_V2S
             | ARM_EXT_V3
             | ARM_EXT_V3M
             | ARM_EXT_V4T 
             | ARM_EXT_V5
             | ARM_EXT_V5E
             | ARM_EXT_V5ExP
             | ARM_EXT_V5J
             | ARM_EXT_V6
             | ARM_EXT_V6K
             | ARM_EXT_V6T2
             | ARM_EXT_V6Z
             | ARM_EXT_V7
             | ARM_EXT_DIV
             | ARM_CEXT_IWMMXT
             | ARM_CEXT_MAVERICK
             | ARM_CEXT_XSCALE
             | FPU_FPA_EXT_V1
             | FPU_NEON_EXT_V1
             | FPU_NEON_FP16
             | FPU_VFP_EXT_V1xD
             | FPU_VFP_EXT_V2
             | FPU_VFP_EXT_V3

data ARMOpcode32 = ARMOpcode32 { opcode32_arch :: [ARMArch]
                               , opcode32_value :: Word32
                               , opcode32_mask :: Word32
                               , opcode32_decoder :: (ARMState, Word32) -> ARMInstruction
                               }
                               
data ARMOpcode16 d = ARMOpcode16 { opcode16_arch  :: [ARMArch]
                                 , opcode16_value :: Word16
                                 , opcode16_mask :: Word16
                                 , opcode16_decoder :: [d]
                                 }

data ARMState = ARMState { pc :: Word32 }

data ARMRegister = R0 | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 
                 | R9 | R10 | R11 | R12 | SP | LR | PC
  deriving (Show, Read, Eq, Enum)

showRegister R1 = "r1"
showRegister R2 = "r2"
showRegister R3 = "r3"
showRegister R4 = "r4"
showRegister R5 = "r5"
showRegister R6 = "r6"
showRegister R7 = "r7"
showRegister R8 = "r8"
showRegister R9 = "r9"
showRegister R10 = "r10"
showRegister R11 = "r11"
showRegister R12 = "r12"
showRegister SP = "sp"
showRegister LR = "lr"
showRegister PC = "pc"


data ARMShift = S_LSL | S_LSR | S_ASR | S_ROR
  deriving (Show, Read, Eq, Enum)
  
data ARMCondition = C_EQ | C_NE | C_CS | C_CC | C_MI | C_PL | C_VS | C_VC
                  | C_HI | C_LS | C_GE | C_LT | C_GT | C_LE | C_AL | C_UND
  deriving (Show, Read, Eq, Enum)
 
data ARMStatusRegister = CPSR | SPSR
  deriving (Show, Read, Eq, Enum)
  
data ARMEndian = BE | LE
  deriving (Show, Read, Eq, Enum)

data Nybble = T | B
  deriving (Show, Read, Eq, Enum)

data Width = Byte | HalfWord | Word | DoubleWord
  deriving (Show, Read, Eq, Enum)

showConditionalOpcode :: ARMConditionalOpcode -> String
showConditionalOpcode (O_B l addr) = printf "b%s 0x%x" (if l then "l" else "") addr
showConditionalOpcode (O_BLX reg) = "blx " ++ showRegister reg
showConditionalOpcode (O_BX reg) = printf "bx %s" (showRegister reg) 
showConditionalOpcode (O_BXJ reg) = printf "bxj %s" (showRegister reg) 


data ARMConditionalOpcode = O_B Bool Int32 -- B, BL
                          | O_BLX ARMRegister -- conditional form
                          | O_BX ARMRegister
                          | O_BXJ ARMRegister
                          
                          | O_AND Bool ARMRegister ARMRegister ARMOpData -- AND, ANDS
                          | O_EOR Bool ARMRegister ARMRegister ARMOpData -- EOR, EORS
                          | O_SUB Bool ARMRegister ARMRegister ARMOpData -- SUB, SUBS
                          | O_RSB Bool ARMRegister ARMRegister ARMOpData -- RSB, RSBS
                          | O_ADD Bool ARMRegister ARMRegister ARMOpData -- ADD, ADDS
                          | O_ADC Bool ARMRegister ARMRegister ARMOpData -- ADC, ADCS
                          | O_RSC Bool ARMRegister ARMRegister ARMOpData -- RSC, RSCS
                          | O_TST Bool ARMRegister ARMRegister ARMOpData -- TST, TSTS
                          | O_TEQ Bool ARMRegister ARMRegister ARMOpData -- TEQ, TEQS
                          | O_CMP Bool ARMRegister ARMRegister ARMOpData -- CMP, CMPS
                          | O_CMN Bool ARMRegister ARMRegister ARMOpData -- CMN, CMNS
                          | O_ORR Bool ARMRegister ARMRegister ARMOpData -- ORR, ORRS
                          | O_MOV Bool ARMRegister ARMOpData -- MOV, MOVS
                          | O_BIC Bool ARMRegister ARMRegister ARMOpData -- BIC, BICS
                          | O_MVN Bool ARMRegister ARMOpData -- MVN, MVNS
                                                    
                          | O_MLA Bool ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_MUL Bool ARMRegister ARMRegister ARMRegister 
                          | O_SMLA Nybble Nybble ARMRegister ARMRegister ARMRegister ARMRegister -- SMLABB, SMLABT, SBMLATB, SMLATT
                          | O_SMLAD Nybble ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_SMLAL (Maybe (Nybble, Nybble)) ARMRegister ARMRegister ARMRegister ARMRegister -- FIXME: first two ArmRegisters are more complicated
                          | O_SMLALD Nybble ARMRegister ARMRegister ARMRegister ARMRegister -- FIXME as above
                          | O_SMLAW Nybble ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_SMLSD Nybble ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_SMLSLD Nybble ARMRegister ARMRegister ARMRegister ARMRegister -- FIXME as above
                          | O_SMMLA Bool ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_SMMUL Bool ARMRegister ARMRegister ARMRegister 
                          | O_SMMLS Bool ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_SMUAD Nybble ARMRegister ARMRegister ARMRegister
                          | O_SMUL Nybble Nybble ARMRegister ARMRegister ARMRegister
                          | O_SMULL
                          | O_SMULW Nybble ARMRegister ARMRegister ARMRegister
                          | O_SMUSD Nybble ARMRegister ARMRegister ARMRegister
                          | O_UMAAL ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_UMLAL
                          | O_UMULL
                          
                          | O_QADD ARMRegister ARMRegister ARMRegister
                          | O_QADD16 ARMRegister ARMRegister ARMRegister
                          | O_QADD8 ARMRegister ARMRegister ARMRegister
                          | O_QADDSUBX ARMRegister ARMRegister ARMRegister
                          | O_QDADD ARMRegister ARMRegister ARMRegister
                          | O_QDSUB ARMRegister ARMRegister ARMRegister
                          | O_QSUB ARMRegister ARMRegister ARMRegister
                          | O_QSUB16 ARMRegister ARMRegister ARMRegister
                          | O_QSUB8 ARMRegister ARMRegister ARMRegister
                          | O_QSUBADDX ARMRegister ARMRegister ARMRegister
                          
                          | O_SADD16 ARMRegister ARMRegister ARMRegister
                          | O_SADD8 ARMRegister ARMRegister ARMRegister
                          | O_SADDSUBX ARMRegister ARMRegister ARMRegister
                          | O_SSUB16 ARMRegister ARMRegister ARMRegister
                          | O_SSUB8 ARMRegister ARMRegister ARMRegister
                          | O_SSUBADDX ARMRegister ARMRegister ARMRegister
                          
                          | O_SHADD16 ARMRegister ARMRegister ARMRegister
                          | O_SHADD8 ARMRegister ARMRegister ARMRegister
                          | O_SHADDSUBX ARMRegister ARMRegister ARMRegister
                          | O_SHSUB16 ARMRegister ARMRegister ARMRegister
                          | O_SHSUB8 ARMRegister ARMRegister ARMRegister
                          | O_SHSUBADDX ARMRegister ARMRegister ARMRegister
                          
                          | O_UADD16 ARMRegister ARMRegister ARMRegister
                          | O_UADD8 ARMRegister ARMRegister ARMRegister
                          | O_UADDSUBX ARMRegister ARMRegister ARMRegister
                          | O_USUB16 ARMRegister ARMRegister ARMRegister
                          | O_USUB8 ARMRegister ARMRegister ARMRegister
                          | O_USUBADDX ARMRegister ARMRegister ARMRegister
                          
                          | O_UHADD16 ARMRegister ARMRegister ARMRegister
                          | O_UHADD8 ARMRegister ARMRegister ARMRegister
                          | O_UHADDSUBX ARMRegister ARMRegister ARMRegister
                          | O_UHSUB16 ARMRegister ARMRegister ARMRegister
                          | O_UHSUB8 ARMRegister ARMRegister ARMRegister
                          | O_UHSUBADDX ARMRegister ARMRegister ARMRegister
                          
                          | O_UQADD16 ARMRegister ARMRegister ARMRegister
                          | O_UQADD8 ARMRegister ARMRegister ARMRegister
                          | O_UQADDSUBX ARMRegister ARMRegister ARMRegister
                          | O_UQSUB16 ARMRegister ARMRegister ARMRegister
                          | O_UQSUB8 ARMRegister ARMRegister ARMRegister
                          | O_UQSUBADDX ARMRegister ARMRegister ARMRegister
                          
                          | O_SXTAB16 ARMRegister ARMRegister ARMOpData -- rotate
                          | O_SXTAB ARMRegister ARMRegister ARMOpData -- rotate
                          | O_SXTAH ARMRegister ARMRegister ARMOpData -- rotate
                          | O_SXTB16 ARMRegister ARMOpData -- rotate
                          | O_SXT Width ARMRegister ARMOpData --rotate only -- ONLY SXTB, SXTH
                          | O_UXTAB16 ARMRegister ARMRegister ARMOpData -- rotate 
                          | O_UXTAB ARMRegister ARMRegister ARMOpData -- rotate
                          | O_UXTAH ARMRegister ARMRegister ARMOpData -- rotate
                          | O_UXTB16 ARMRegister ARMOpData -- rotate
                          | O_UXT Width ARMRegister ARMOpData -- rotate -- UXTB, UXTH
                          
                          | O_CLZ ARMRegister ARMRegister
                          | O_USAD8 ARMRegister ARMRegister ARMRegister 
                          | O_USADA8 ARMRegister ARMRegister ARMRegister ARMRegister
                          | O_PKHBT ARMRegister ARMRegister ARMOpData -- rotate/shift
                          | O_PKHTB ARMRegister ARMRegister ARMOpData -- rotate/shift
                          | O_REV ARMRegister ARMRegister
                          | O_REV16 ARMRegister ARMRegister
                          | O_REVSH ARMRegister ARMRegister
                          | O_SEL ARMRegister ARMRegister ARMRegister
                          | O_SSAT ARMRegister Word8 ARMOpData -- rotate/shift
                          | O_SSAT16 ARMRegister Word8 ARMRegister
                          | O_USAT ARMRegister Word8 ARMOpData -- rotate/shift
                          | O_USAT16 ARMRegister Word8 ARMRegister
                          
                          | O_MRS ARMRegister ARMStatusRegister
                          | O_MSR 
                          
                          | O_LDR Width ARMRegister ARMOpMemory -- LDR, LDRB, LDRH, LDRD
                          | O_STR Width ARMRegister ARMOpMemory -- STR, STRB, STRH, STRD
                          | O_LDRS Bool ARMRegister ARMOpMemory -- LDRSB, LDRSH
                          | O_LDRT Bool ARMRegister ARMOpMemory -- LDRT LDRBT
                          | O_STRT Bool ARMRegister ARMOpMemory -- STRT, STRBT
                          | O_LDREX
                          | O_STREX
                          
                          | O_LDM -- Note that there are three different forms
                          | O_STM -- Note that there are two different forms
                          
                          | O_SWP Bool ARMRegister ARMRegister ARMRegister -- SWP, SWPB
                          
                          | O_SWI Word32
  deriving (Show, Read, Eq)

data ARMUnconditionalOpcode = O_CPS
                            | O_SETEND ARMEndian
                            | O_RFE
                            | O_BKPT Word8
                            | O_PLD
                            | O_SRS
                            | O_BLXUC Int32 -- unconditional BLX
  deriving (Show, Read, Eq)
  
data ARMOpData = OP_Imm Int
               | OP_Reg ARMRegister
               | OP_RegShiftImm ARMShift Int ARMRegister 
               | OP_RegShiftReg ARMShift ARMRegister ARMRegister
               | OP_RegShiftRRX ARMRegister
  deriving (Show, Read, Eq)

{-}  
data ARMOpRegister = OP_Reg ARMRegister
                   | OP_RegBang ARMRegister
  deriving (Show, Read, Eq)
-}
data ARMOpMemory = OP_MemRegImm ARMRegister Int Bool 
                 | OP_MemRegReg ARMRegister ARMRegister Bool
                 | OP_MemRegShiftReg ARMRegister ARMRegister ARMShift Int Bool
                 | OP_MemRegPostImm ARMRegister Int
                 | OP_MemRegPostReg ARMRegister ARMRegister
                 | OP_MemRegPostShiftReg ARMRegister ARMRegister ARMShift Int
  deriving (Show, Read, Eq)
  
data ARMOpMultiple = OP_Regs [ARMRegister]
                   | OP_RegsCaret [ARMRegister]
  deriving (Show, Read, Eq)
     
data ARMInstruction = ARMUnconditionalInstruction ARMUnconditionalOpcode
                    | ARMConditionalInstruction ARMCondition ARMConditionalOpcode
  deriving (Show, Read, Eq)
  
{-            
data ARMInstruction = ARMInstruction { insn_opcode :: ARMOpcode
                                     , insn_condition :: ARMCondition
                                     , insn_operands :: [ARMOperand]
                                     }
-}

bitRange :: (Integral a, Bits a) => Int -> Int -> a -> a
bitRange start end i = ((i `shiftR` start) .&. ((2 `shiftL` (end - start)) - 1))

armConditions = ["eq", "ne", "cs", "cc", "mi", "pl", "vs", "vc", "hi"
                ,"ls", "ge", "lt", "gt", "le", "", "<und>", ""]

armRegisters = ["r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8"
               ,"r9", "r10", "r11", "r12", "sp", "lr", "pc"]

armShift = ["lsl", "lsr", "asr", "ror"]

type ARMDecoder a = (ARMState, Word32) -> a

{-
printARMAddress :: ARMDecoder String
printARMAddress (s, a) | (a .&. 0xf0000) == 0xf0000 && (a .&. 0x2000000) == 0 = 
                        let offset = a .&. 0xfff in
                          case a .&. 0x1000000 /= 0 of
                            True -> "[pc, #" ++ (show $ if (a .&. 0x800000) == 0 then -offset else offset) ++ (if (a .&. 0x200000) /= 0 then "]!" else "]")
                            _    -> "[pc], " ++ (show offset)
                    | otherwise = 
                          "[" ++ (armRegisters !! (((fromIntegral a) `shiftR` 16 ) .&. 0xf)) ++ case a .&. 0x1000000 /= 0 of
                            False -> if (a .&. 0x2000000) == 0 then
                                       let offset = a .&. 0xfff in
                                         if offset /= 0 then
                                           "], #" ++ if (a .&. 0x800000) == 0 then show (-(fromIntegral offset :: Int32)) else show offset
                                           else "]"
                                       else "], #" ++ (if (a .&. 0x800000) == 0 then "-" else "") ++ (armDecodeShift a False)
                            _     -> if (a .&. 0x2000000) == 0 then
                                       let offset = a .&. 0xfff in
                                         (if offset /= 0 then
                                            ", #" ++ if (a .&. 0x800000) == 0 then show (-(fromIntegral offset :: Int32)) else show offset
                                            else "") ++ if (a .&. 0x200000) /= 0 then "]!" else "]"
                                       else ", #" ++ (if (a .&. 0x800000) == 0 then "-" else "") ++ (armDecodeShift a False)
                                          ++ if (a .&. 0x200000) /= 0 then "]!" else "]"
-}

armDecodeShift :: Word32 -> Bool -> ARMOpData
armDecodeShift i p =  if i .&. 0xff0 /= 0 then
                        if i .&. 0x10 == 0 then
                          let amount = (i .&. 0xf80) `shiftR` 7
                              shift = ((fromIntegral i) .&. 0x60) `shiftR` 5 in
                            if amount == 0 && shift == 3 then  OP_RegShiftRRX (toEnum ((fromIntegral i) .&. 0xf)) 
                              else  OP_RegShiftImm (toEnum shift) (fromIntegral amount) (toEnum ((fromIntegral i) .&. 0xf)) 
                          else  OP_RegShiftImm (toEnum (((fromIntegral i) .&. 0x60) `shiftR` 5)) (toEnum (((fromIntegral i) .&. 0xf00 `shiftR` 8))) (toEnum ((fromIntegral i) .&. 0xf)) 
                        else OP_Reg (toEnum ((fromIntegral i) .&. 0xf))

arm_const :: String -> ARMDecoder String
arm_const x (s, i) = x

arm_constint :: Int -> ARMDecoder String
arm_constint x (s, i) = show x

--arm_a :: ARMDecoder String
--arm_a = printARMAddress 

-- FIXME: wow, this is pretty ugly...
arm_s :: ARMDecoder String
arm_s (s, i) | i .&. 0x4f0000 == 0x4f0000 = "[pc, #" ++ (show $ (if i .&. 0x800000 == 0 then -1 else 1) * ((i .&. 0xf00) `shiftR` 4) .|. (i .&. 0xf)) ++ "]"
          | i .&. 0x1000000 /= 0 = case i .&. 0x400000 of
              0x400000 -> "[" ++ (armRegisters !! (((fromIntegral i) `shiftR` 16) .&. 0xf)) ++ 
                              (let offset = ((i .&. 0xf00) `shiftR` 4) .|. (i .&. 0xf) in 
                                (if offset /= 0 then if (i .&. 0x800000) == 0 then show (-offset) else show offset else "") 
                                 ++ (if (i .&. 0x200000) /= 0 then "]!" else "]"))
              _        -> "[" ++ (armRegisters !! (((fromIntegral i) `shiftR` 16) .&. 0xf)) ++ 
                              (if (i .&. 0x800000) == 0 then "-" ++ (armRegisters !! ((fromIntegral i) .&. 0xf)) else (armRegisters !! ((fromIntegral i) .&. 0xf))) ++ (if (i .&. 0x200000) /= 0 then "]!" else "]")
          | otherwise = case i .&. 0x400000 of
              0x400000 -> "[" ++ (armRegisters !! (((fromIntegral i) `shiftR` 16) .&. 0xf)) ++ 
                              (let offset = ((i .&. 0xf00) `shiftR` 4) .|. (i .&. 0xf) in 
                                (if offset /= 0 then if (i .&. 0x800000) == 0 then show (-offset) else show offset else "") 
                                 ++ "]")
              _        -> "[" ++ (armRegisters !! (((fromIntegral i) `shiftR` 16) .&. 0xf)) ++ "], " ++ (if (i .&. 0x800000) == 0 then "-" ++ (armRegisters !! ((fromIntegral i) .&. 0xf)) else (armRegisters !! ((fromIntegral i) .&. 0xf)))

arm_b :: ARMDecoder Int32
arm_b (s, i) = ((((fromIntegral i :: Int32) .&. 0xffffff) `xor` 0x800000) - 0x800000) * 4 + (fromIntegral $ pc s) + 8

arm_c :: ARMDecoder ARMCondition
arm_c (_, i) = toEnum $ fromIntegral ((i `shiftR` 28) .&. 0xf)

arm_m :: ARMDecoder String
arm_m (s, i) = "{" ++ (intercalate ", " . filter (not . null) $ map (\x -> if i .&. (1 `shiftL` x) /= 0 then armRegisters !! x else "") [0..15]) ++ "}"

arm_o :: ARMDecoder ARMOpData
arm_o (_, i) | i .&. 0x2000000 /= 0 = OP_Imm . fromIntegral $ (i .&. 0xff) `rotateR` (((fromIntegral i) .&. 0xf00) `shiftR` 7)
             | otherwise = armDecodeShift i True

arm_p :: ARMDecoder String
arm_p (s, i) = if (i .&. 0xf000) == 0xf000 then "p" else "" 

arm_t :: ARMDecoder String
arm_t (s, i) = if (i .&. 0x1200000) == 0x200000 then "t" else ""

arm_q :: ARMDecoder ARMOpData
arm_q (s, i) = armDecodeShift i False

arm_e :: ARMDecoder String
arm_e (s, i) = show $ (i .&. 0xf) .|. ((i .&. 0xfff00) `shiftR` 4)

arm_B :: ARMDecoder Int32
arm_B (s, i) = let offset = ((if i .&. 0x800000 /= 0 then 0xff else 0) + (i .&. 0xffffff)) `shiftL` 2 
                   address = offset + (pc s) + 8 + (if i .&. 0x1000000 /= 0 then 2 else 0) in
                     fromIntegral address
              
-- FIXME: this is ugly
arm_C :: ARMDecoder String
arm_C (s, i) = '_' : (if i .&. 0x80000 /= 0 then "f" else "" ++ 
                   if i .&. 0x40000 /= 0 then "s" else "" ++
                   if i .&. 0x20000 /= 0 then "x" else "" ++
                   if i .&. 0x10000 /= 0 then "c" else "")

arm_U :: ARMDecoder String
arm_U (s, i) = case i .&. 0xf of
              0xf -> "sy"
              0x7 -> "un"
              0xe -> "st"
              0x6 -> "unst"
              x   -> show x

--arm_P :: ARMDecoder String
--arm_P (s, i) = printARMAddress (s, (i .|. (1 `shiftL` 24)))

arm_r :: Int -> Int -> ARMDecoder ARMRegister
arm_r start end (_, i) = toEnum (bitRange start end $ fromIntegral i)

arm_d :: Int -> Int -> ARMDecoder Int
arm_d start end (_, i) = bitRange start end $ fromIntegral i

arm_W :: (Integral a, Bits a) => Int -> Int -> ARMDecoder a
arm_W start end (_, i) = (+1) . bitRange start end $ fromIntegral i

arm_x :: Int -> Int -> ARMDecoder Int
arm_x = arm_d

arm_X :: Int -> Int -> ARMDecoder Word32
arm_X start end (s, i) = (.&. 0xf) . bitRange start end $ i

arm_arr :: Int -> Int -> [Char] -> ARMDecoder String
arm_arr start end c (s, i) = return $ c !! (bitRange start end $ fromIntegral i)

arm_E :: ARMDecoder String
arm_E (s, i) = let msb = (i .&. 0x1f0000) `shiftR` 16
                   lsb = (i .&. 0xf80) `shiftR` 7
                   width = msb - lsb + 1 in
                 if width > 0 then
                   "#" ++ (show lsb) ++ ", #" ++ (show width)
                   else "(invalid " ++ (show lsb) ++ ":" ++ (show msb) ++ ")"            

arm_V :: ARMDecoder String
arm_V (s, i) = "#" ++ (show $ (i .&. 0xf0000) `shiftR` 4 .|. (i .&. 0xfff))

{-
arm_square :: ARMDecoder -> ARMDecoder
arm_square d = ((("[" ++) . (++ "]")) .) . d

arm_curly :: ARMDecoder -> ARMDecoder
arm_curly d = ((("{" ++) . (++ "}")) .) . d

arm_lsl :: ARMDecoder -> ARMDecoder
arm_lsl d = (("lsl " ++) .) . d

arm_asr :: ARMDecoder -> ARMDecoder
arm_asr d = (("asr " ++) .) . d

arm_ror :: ARMDecoder -> ARMDecoder
arm_ror d = (("ror " ++) .) . d
-}

arm_bit bit (_, i) = bitRange bit bit i

arm_bool bit s = arm_bit bit s == 1

arm_uncond = liftM ARMUnconditionalInstruction

arm_cond = liftM2 ARMConditionalInstruction arm_c

armOpcodes = 
  [--ARMOpcode32 [ARM_EXT_V1] 0xe1a00000 0xffffffff [arm_const "nop"]
   ARMOpcode32 [ARM_EXT_V4T, ARM_EXT_V5] 0x012FFF10 0x0ffffff0 (arm_cond $ liftM O_BX (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V2] 0x00000090 0x0fe000f0 (arm_cond $ liftM4 O_MUL (arm_bool 20) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V2] 0x00200090 0x0fe000f0 (arm_cond $ liftM5 O_MLA (arm_bool 20) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  --, ARMOpcode32 [ARM_EXT_V2S] 0x01000090 0x0fb00ff0 [arm_const "swp", arm_char1 22 22 'b', arm_c, arm_r 12 15, arm_r 0 3, arm_square (arm_r 16 19)]
  --, ARMOpcode32 [ARM_EXT_V3M] 0x00800090 0x0fa000f0 [arm_arr 22 22 ['s', 'u'], arm_const "mull", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_r 16 19, arm_r 0 3, arm_r 8 11]
  --, ARMOpcode32 [ARM_EXT_V3M] 0x00800090 0x0fa000f0 [arm_arr 22 22 ['s', 'u'], arm_const "mlal", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_r 16 19, arm_r 0 3, arm_r 8 11]
  --, ARMOpcode32 [ARM_EXT_V7] 0xf450f000 0xfd70f000 [arm_const "pli", arm_P]
  --, ARMOpcode32 [ARM_EXT_V7] 0x0320f0f0 0x0ffffff0 [arm_const "dbg", arm_c, arm_d 0 3]
  --, ARMOpcode32 [ARM_EXT_V7] 0xf57ff050 0x0ffffff0 [arm_const "dmb", arm_U]
  --, ARMOpcode32 [ARM_EXT_V7] 0xf57ff040 0x0ffffff0 [arm_const "dsb", arm_U]
  --, ARMOpcode32 [ARM_EXT_V7] 0xf57ff060 0x0ffffff0 [arm_const "isb", arm_U]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x07c0001f 0x0fe0007f [arm_const "bfc", arm_c, arm_r 12 15, arm_E] 
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x07c00010 0x0fe00070 [arm_const "bfi", arm_c, arm_r 12 15, arm_r 0 3, arm_E]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x00600090 0x0ff000f0 [arm_const "mls", arm_c, arm_r 0 3, arm_r 8 11, arm_r 12 15]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x006000b0 0x0f7000f0 [arm_const "strht", arm_c, arm_r 12 15, arm_s]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x00300090 0x0f300090 [arm_const "ldr", arm_char1 6 6 's', arm_arr 5 5 ['h','b'], arm_c, arm_r 12 15, arm_s]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x03000000 0x0ff00000 [arm_const "movw", arm_c, arm_r 12 15, arm_V]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x03400000 0x0ff00000 [arm_const "movt", arm_c, arm_r 12 15, arm_V]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x06ff0f30 0x0fff0ff0 [arm_const "rbit", arm_c, arm_r 12 15, arm_r 0 3]
  --, ARMOpcode32 [ARM_EXT_V6T2] 0x07a00050 0x0fa00070 [arm_arr 22 22 ['u', 's'], arm_const "bfx", arm_c, arm_r 12 15, arm_r 0 3, arm_d 7 11, arm_W 16 20]
  --, ARMOpcode32 [ARM_EXT_V6Z] 0x01600070 0x0ff000f0 [arm_const "smc", arm_c, arm_e]
  --, ARMOpcode32 [ARM_EXT_V6K] 0xf57ff01f 0xffffffff [arm_const "clrex"]
  --, ARMOpcode32 [ARM_EXT_V6K] 0x01d00f9f 0x0ff00fff [arm_const "ldrexb", arm_c, arm_r 12 15, arm_square (arm_r 16 19)]
  --, ARMOpcode32 [ARM_EXT_V6K] 0x01b00f9f 0x0ff00fff [arm_const "ldrexd", arm_c, arm_r 12 15, arm_square (arm_r 16 19)] 
  --, ARMOpcode32 [ARM_EXT_V6K] 0x01f00f9f 0x0ff00fff [arm_const "ldrexh", arm_c, arm_r 12 15, arm_square (arm_r 16 19)] 
  --, ARMOpcode32 [ARM_EXT_V6K] 0x01c00f90 0x0ff00ff0 [arm_const "strexb", arm_c, arm_r 12 15, arm_r 0 3, arm_square (arm_r 16 19)]
  --, ARMOpcode32 [ARM_EXT_V6K] 0x01a00f90 0x0ff00ff0 [arm_const "strexd", arm_c, arm_r 12 15, arm_r 0 3, arm_square (arm_r 16 19)] 
  --, ARMOpcode32 [ARM_EXT_V6K] 0x01e00f90 0x0ff00ff0 [arm_const "strexh", arm_c, arm_r 12 15, arm_r 0 3, arm_square (arm_r 16 19)] 
  --, ARMOpcode32 [ARM_EXT_V6K] 0x0320f001 0x0fffffff [arm_const "yield", arm_c]
  --, ARMOpcode32 [ARM_EXT_V6K] 0x0320f002 0x0fffffff [arm_const "wfe", arm_c] 
  --, ARMOpcode32 [ARM_EXT_V6K] 0x0320f003 0x0fffffff [arm_const "wfi", arm_c]
  --, ARMOpcode32 [ARM_EXT_V6K] 0x0320f004 0x0fffffff [arm_const "sev", arm_c]
  --, ARMOpcode32 [ARM_EXT_V6K] 0x0320f000 0x0fffff00 [arm_const "nop", arm_c, arm_curly (arm_d 0 7)]
  --, ARMOpcode32 [ARM_EXT_V6] 0xf1080000 0xfffffe3f [arm_const "cpsie", arm_char1 8 8 'a', arm_char1 7 7 'i', arm_char1 6 6 'f']
  --, ARMOpcode32 [ARM_EXT_V6] 0xf10a0000 0xfffffe20 [arm_const "cpsie", arm_char1 8 8 'a', arm_char1 7 7 'i', arm_char1 6 6 'f', arm_d 0 4] 
  --, ARMOpcode32 [ARM_EXT_V6] 0xf10C0000 0xfffffe3f [arm_const "cpsid", arm_char1 8 8 'a', arm_char1 7 7 'i', arm_char1 6 6 'f'] 
  --, ARMOpcode32 [ARM_EXT_V6] 0xf10e0000 0xfffffe20 [arm_const "cpsid", arm_char1 8 8 'a', arm_char1 7 7 'i', arm_char1 6 6 'f', arm_d 0 4] 
  --, ARMOpcode32 [ARM_EXT_V6] 0xf1000000 0xfff1fe20 [arm_const "cps", arm_d 0 4]
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800010 0x0ff00ff0 (arm_cond $ liftM3 O_PKHBT     (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800010 0x0ff00070 (arm_cond $ liftM3 O_PKHBT     (arm_r 12 15) (arm_r 16 19) (liftM2 (OP_RegShiftImm S_LSL) (arm_d 7 11) (arm_r 0 3)))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800050 0x0ff00ff0 (arm_cond $ liftM3 O_PKHTB     (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ASR 32 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800050 0x0ff00070 (arm_cond $ liftM3 O_PKHTB     (arm_r 12 15) (arm_r 16 19) (liftM2 (OP_RegShiftImm S_ASR) (arm_d 7 11) (arm_r 0 3)))
  --,ARMOpcode32 [ARM_EXT_V6] 0x01900f9f 0x0ff00fff (arm_cond $ liftM3 O_LDREX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06200f10 0x0ff00ff0 (arm_cond $ liftM3 O_QADD16    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06200f90 0x0ff00ff0 (arm_cond $ liftM3 O_QADD8     (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06200f30 0x0ff00ff0 (arm_cond $ liftM3 O_QADDSUBX  (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06200f70 0x0ff00ff0 (arm_cond $ liftM3 O_QSUB16    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06200ff0 0x0ff00ff0 (arm_cond $ liftM3 O_QSUB8     (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06200f50 0x0ff00ff0 (arm_cond $ liftM3 O_QSUBADDX  (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06100f10 0x0ff00ff0 (arm_cond $ liftM3 O_SADD16    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06100f90 0x0ff00ff0 (arm_cond $ liftM3 O_SADD8     (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  --,ARMOpcode32 [ARM_EXT_V6] 0x06100f30 0x0ff00ff0 (arm_cond $ liftM3 O_SADDADDX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3)) -- http://sourceware.org/bugzilla/show_bug.cgi?id=6773
  ,ARMOpcode32 [ARM_EXT_V6] 0x06300f10 0x0ff00ff0 (arm_cond $ liftM3 O_SHADD16   (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06300f90 0x0ff00ff0 (arm_cond $ liftM3 O_SHADD8    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06300f30 0x0ff00ff0 (arm_cond $ liftM3 O_SHADDSUBX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06300f70 0x0ff00ff0 (arm_cond $ liftM3 O_SHSUB16   (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06300ff0 0x0ff00ff0 (arm_cond $ liftM3 O_SHSUB8    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06300f50 0x0ff00ff0 (arm_cond $ liftM3 O_SHSUBADDX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06100f70 0x0ff00ff0 (arm_cond $ liftM3 O_SSUB16    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06100ff0 0x0ff00ff0 (arm_cond $ liftM3 O_SSUB8     (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06100f50 0x0ff00ff0 (arm_cond $ liftM3 O_SSUBADDX  (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06500f10 0x0ff00ff0 (arm_cond $ liftM3 O_UADD16    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06500f90 0x0ff00ff0 (arm_cond $ liftM3 O_UADD8     (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06500f30 0x0ff00ff0 (arm_cond $ liftM3 O_UADDSUBX  (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06700f10 0x0ff00ff0 (arm_cond $ liftM3 O_UHADD16   (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06700f90 0x0ff00ff0 (arm_cond $ liftM3 O_UHADD8    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06700f30 0x0ff00ff0 (arm_cond $ liftM3 O_UHADDSUBX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06700f70 0x0ff00ff0 (arm_cond $ liftM3 O_UHSUB16   (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06700ff0 0x0ff00ff0 (arm_cond $ liftM3 O_UHSUB8    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06700f50 0x0ff00ff0 (arm_cond $ liftM3 O_UHSUBADDX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06600f10 0x0ff00ff0 (arm_cond $ liftM3 O_UQADD16   (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06600f90 0x0ff00ff0 (arm_cond $ liftM3 O_UQADD8    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06600f30 0x0ff00ff0 (arm_cond $ liftM3 O_UQADDSUBX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06600f70 0x0ff00ff0 (arm_cond $ liftM3 O_UQSUB16   (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06600ff0 0x0ff00ff0 (arm_cond $ liftM3 O_UQSUB8    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06600f50 0x0ff00ff0 (arm_cond $ liftM3 O_UQSUBADDX (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06500f70 0x0ff00ff0 (arm_cond $ liftM3 O_USUB16    (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06500ff0 0x0ff00ff0 (arm_cond $ liftM3 O_USUB8     (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06500f50 0x0ff00ff0 (arm_cond $ liftM3 O_USUBADDX  (arm_r 12 15) (arm_r 16 19) (arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06bf0f30 0x0fff0ff0 (arm_cond $ liftM2 O_REV       (arm_r 12 15) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06bf0fb0 0x0fff0ff0 (arm_cond $ liftM2 O_REV16     (arm_r 12 15) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ff0fb0 0x0fff0ff0 (arm_cond $ liftM2 O_REVSH     (arm_r 12 15) (arm_r 0 3))
  --, ARMOpcode32 [ARM_EXT_V6] 0xf8100a00 0xfe50ffff [arm_const "rfe", arm_arr 23 23 ['i', 'd'], arm_arr 24 24 ['b', 'a'], arm_r 16 19, arm_char1 21 21 '!']
  ,ARMOpcode32 [ARM_EXT_V6] 0x06bf0070 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT HalfWord) (arm_r 12 15) (OP_Reg . arm_r 0 3))--, ARMOpcode32 [ARM_EXT_V6] 0x06bf0070 0x0fff0ff0 [arm_const "sxth", arm_c, arm_r 12 15, arm_r 0 3]
  ,ARMOpcode32 [ARM_EXT_V6] 0x06bf0470 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT HalfWord) (arm_r 12 15) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))--, ARMOpcode32 [ARM_EXT_V6] 0x06bf0470 0x0fff0ff0 [arm_const "sxth", arm_c, arm_r 12 15, arm_r 0 3, arm_ror (arm_constint 8)] 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06bf0870 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT HalfWord) (arm_r 12 15) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))--, ARMOpcode32 [ARM_EXT_V6] 0x06bf0870 0x0fff0ff0 [arm_const "sxth", arm_c, arm_r 12 15, arm_r 0 3, arm_ror (arm_constint 16)]
  ,ARMOpcode32 [ARM_EXT_V6] 0x06bf0c70 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT HalfWord) (arm_r 12 15) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))--, ARMOpcode32 [ARM_EXT_V6] 0x06bf0c70 0x0fff0ff0 [arm_const "sxth", arm_c, arm_r 12 15, arm_r 0 3, arm_ror (arm_constint 24)]
  ,ARMOpcode32 [ARM_EXT_V6] 0x068f0070 0x0fff0ff0 (arm_cond $ liftM2 O_SXTB16         (arm_r 12 15) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x068f0470 0x0fff0ff0 (arm_cond $ liftM2 O_SXTB16         (arm_r 12 15) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x068f0870 0x0fff0ff0 (arm_cond $ liftM2 O_SXTB16         (arm_r 12 15) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x068f0c70 0x0fff0ff0 (arm_cond $ liftM2 O_SXTB16         (arm_r 12 15) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06af0070 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT Byte)     (arm_r 12 15) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06af0470 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT Byte)     (arm_r 12 15) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06af0870 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT Byte)     (arm_r 12 15) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06af0c70 0x0fff0ff0 (arm_cond $ liftM2 (O_SXT Byte)     (arm_r 12 15) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ff0070 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT HalfWord) (arm_r 12 15) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ff0470 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT HalfWord) (arm_r 12 15) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ff0870 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT HalfWord) (arm_r 12 15) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ff0c70 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT HalfWord) (arm_r 12 15) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06cf0070 0x0fff0ff0 (arm_cond $ liftM2 O_UXTB16         (arm_r 12 15) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06cf0470 0x0fff0ff0 (arm_cond $ liftM2 O_UXTB16         (arm_r 12 15) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06cf0870 0x0fff0ff0 (arm_cond $ liftM2 O_UXTB16         (arm_r 12 15) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06cf0c70 0x0fff0ff0 (arm_cond $ liftM2 O_UXTB16         (arm_r 12 15) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ef0070 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT Byte)     (arm_r 12 15) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ef0470 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT Byte)     (arm_r 12 15) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ef0870 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT Byte)     (arm_r 12 15) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06ef0c70 0x0fff0ff0 (arm_cond $ liftM2 (O_UXT Byte)     (arm_r 12 15) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06b00070 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAH          (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06b00470 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAH          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06b00870 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAH          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 16 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06b00c70 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAH          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 24 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800070 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800470 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))  
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800870 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 16 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800c70 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 24 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00070 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB          (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00470 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00870 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 16 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00c70 0x0ff00ff0 (arm_cond $ liftM3 O_SXTAB          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 24 . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06f00070 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAH          (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06f00470 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAH          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))  
  ,ARMOpcode32 [ARM_EXT_V6] 0x06f00870 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAH          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 16 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06f00c70 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAH          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 24 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06c00070 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06c00470 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))  
  ,ARMOpcode32 [ARM_EXT_V6] 0x06c00870 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 16 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06c00c70 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB16        (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 24 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00070 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB          (arm_r 12 15) (arm_r 16 19) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00470 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 8 . arm_r 0 3))  
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00870 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 16 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00c70 0x0ff00ff0 (arm_cond $ liftM3 O_UXTAB          (arm_r 12 15) (arm_r 16 19) (OP_RegShiftImm S_ROR 24 . arm_r 0 3)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06800fb0 0x0ff00ff0 (arm_cond $ liftM3 O_SEL            (arm_r 12 15) (arm_r 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0xf1010000 0xfffffc00 (arm_uncond $ liftM O_SETEND (toEnum . fromIntegral . arm_bit 9))
  ,ARMOpcode32 [ARM_EXT_V6] 0x0700f010 0x0ff0f0d0 (arm_cond $ liftM4 O_SMUAD   (toEnum . fromIntegral . arm_bit 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11)) -- TODO: double check enum direction is correct for first arg
  ,ARMOpcode32 [ARM_EXT_V6] 0x0700f050 0x0ff0f0d0 (arm_cond $ liftM4 O_SMUSD   (toEnum . fromIntegral . arm_bit 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V6] 0x07000010 0x0ff000d0 (arm_cond $ liftM5 O_SMLAD   (toEnum . fromIntegral . arm_bit 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  ,ARMOpcode32 [ARM_EXT_V6] 0x07400010 0x0ff000d0 (arm_cond $ liftM5 O_SMLALD  (toEnum . fromIntegral . arm_bit 5) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V6] 0x07000050 0x0ff000d0 (arm_cond $ liftM5 O_SMLSD   (toEnum . fromIntegral . arm_bit 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x07400050 0x0ff000d0 (arm_cond $ liftM5 O_SMLSLD  (toEnum . fromIntegral . arm_bit 5) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V6] 0x0750f010 0x0ff0f0d0 (arm_cond $ liftM4 O_SMMUL   (arm_bool 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V6] 0x07500010 0x0ff000d0 (arm_cond $ liftM5 O_SMMLA   (arm_bool 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  ,ARMOpcode32 [ARM_EXT_V6] 0x075000d0 0x0ff000d0 (arm_cond $ liftM5 O_SMMLS   (arm_bool 5) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  --,ARMOpcode32 [ARM_EXT_V6] 0xf84d0500 0xfe5fffe0 (arm_uncond $ O_SRS    arm_arr 23 23 ['i' 'd'] arm_arr 24 24 ['b' 'a'] arm_r 16 19 arm_char1 21 21 '!' arm_d 0 4]
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00010 0x0fe00ff0 (arm_cond $ liftM3 O_SSAT    (arm_r 12 15) (arm_W 16 20) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00010 0x0fe00070 (arm_cond $ liftM3 O_SSAT    (arm_r 12 15) (arm_W 16 20) (liftM2 (OP_RegShiftImm S_LSL) (arm_d 7 11) (arm_r 0 3)))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00050 0x0fe00070 (arm_cond $ liftM3 O_SSAT    (arm_r 12 15) (arm_W 16 20) (liftM2 (OP_RegShiftImm S_ASR) (arm_d 7 11) (arm_r 0 3)))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06a00f30 0x0ff00ff0 (arm_cond $ liftM3 O_SSAT16  (arm_r 12 15) (arm_W 16 19) (arm_r 0 3))
  --ARMOpcode32 [ARM_EXT_V6] 0x01800f90 0x0ff00ff0 (arm_cond $ liftM3 O_strex  arm_r 12 15 arm_r 12 15 arm_r 0 3 arm_square (arm_r 16 19)] 
  ,ARMOpcode32 [ARM_EXT_V6] 0x00400090 0x0ff000f0 (arm_cond $ liftM4 O_UMAAL   (arm_r 12 15) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3)) -- (arm_r 8 11)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x0780f010 0x0ff0f0f0 (arm_cond $ liftM3 O_USAD8   (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V6] 0x07800010 0x0ff000f0 (arm_cond $ liftM4 O_USADA8  (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15)) 
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00010 0x0fe00ff0 (arm_cond $ liftM3 O_USAT    (arm_r 12 15) (arm_W 16 20) (OP_Reg . arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00010 0x0fe00070 (arm_cond $ liftM3 O_USAT    (arm_r 12 15) (arm_W 16 20) (liftM2 (OP_RegShiftImm S_LSL) (arm_d 7 11) (arm_r 0 3)))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00050 0x0fe00070 (arm_cond $ liftM3 O_USAT    (arm_r 12 15) (arm_W 16 20) (liftM2 (OP_RegShiftImm S_ASR) (arm_d 7 11) (arm_r 0 3)))
  ,ARMOpcode32 [ARM_EXT_V6] 0x06e00f30 0x0ff00ff0 (arm_cond $ liftM3 O_USAT16  (arm_r 12 15) (arm_W 16 19) (arm_r 0 3))
  ,ARMOpcode32 [ARM_EXT_V5J] 0x012fff20 0x0ffffff0 (arm_cond $ liftM O_BXJ     (arm_r 0 3))
  --,ARMOpcode32 [ARM_EXT_V5] 0xe1200070 0xfff000f0 (arm_uncond $ liftM O_BKPT (\x -> ((`shiftL` 24) . fromIntegral . arm_X 16 19 x) .|. ((`shiftL` 16) . fromIntegral . arm_X 12 15 x) .|. ((`shiftL` 8) . fromIntegral . arm_X 8 11 x) .|. ((fromIntegral . arm_X 0 3) x))) -- compound number
  ,ARMOpcode32 [ARM_EXT_V5] 0xfa000000 0xfe000000 (arm_uncond $ liftM O_BLXUC arm_B) --, ARMOpcode32 [ARM_EXT_V5] 0xfa000000 0xfe000000 [arm_const "blx", arm_B]
  ,ARMOpcode32 [ARM_EXT_V5] 0x012fff30 0x0ffffff0 (arm_cond $ liftM O_BLX (arm_r 0 3)) --, ARMOpcode32 [ARM_EXT_V5] 0x012fff30 0x0ffffff0 [arm_const "blx", arm_c, arm_r 0 3]
  ,ARMOpcode32 [ARM_EXT_V5] 0x016f0f10 0x0fff0ff0 (arm_cond $ liftM2 O_CLZ (arm_r 12 15) (arm_r 0 3)) --, ARMOpcode32 [ARM_EXT_V5] 0x016f0f10 0x0fff0ff0 [arm_const "clz", arm_c, arm_r 12 15, arm_r 0 3]
  --, ARMOpcode32 [ARM_EXT_V5E] 0x000000d0 0x0e1000f0 [arm_const "ldrd", arm_c, arm_r 12 15, arm_s]
  --, ARMOpcode32 [ARM_EXT_V5E] 0x000000f0 0x0e1000f0 [arm_const "strd", arm_c, arm_r 12 15, arm_s]
  --, ARMOpcode32 [ARM_EXT_V5E] 0xf450f000 0xfc70f000 [arm_const "pld", arm_a]
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01000080 0x0ff000f0 (arm_cond $ liftM4 (O_SMLA B B) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x010000a0 0x0ff000f0 (arm_cond $ liftM4 (O_SMLA T B) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x010000c0 0x0ff000f0 (arm_cond $ liftM4 (O_SMLA B T) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x010000e0 0x0ff000f0 (arm_cond $ liftM4 (O_SMLA T T) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11) (arm_r 12 15))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01400080 0x0ff000f0 (arm_cond $ liftM4 (O_SMLAL $ Just (B, B)) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x014000a0 0x0ff000f0 (arm_cond $ liftM4 (O_SMLAL $ Just (T, B)) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x014000c0 0x0ff000f0 (arm_cond $ liftM4 (O_SMLAL $ Just (B, T)) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x014000e0 0x0ff000f0 (arm_cond $ liftM4 (O_SMLAL $ Just (T, T)) (arm_r 12 15) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01600080 0x0ff0f0f0 (arm_cond $ liftM3 (O_SMUL B B) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x016000a0 0x0ff0f0f0 (arm_cond $ liftM3 (O_SMUL T B) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x016000c0 0x0ff0f0f0 (arm_cond $ liftM3 (O_SMUL B T) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x016000e0 0x0ff0f0f0 (arm_cond $ liftM3 (O_SMUL T T) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x012000a0 0x0ff0f0f0 (arm_cond $ liftM3 (O_SMULW B) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x012000e0 0x0ff0f0f0 (arm_cond $ liftM3 (O_SMULW T) (arm_r 16 19) (arm_r 0 3) (arm_r 8 11))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01000050 0x0ff00ff0 (arm_cond $ liftM3 O_QADD   (arm_r 12 15) (arm_r 0 3) (arm_r 16 19))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01400050 0x0ff00ff0 (arm_cond $ liftM3 O_QDADD  (arm_r 12 15) (arm_r 0 3) (arm_r 16 19))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01200050 0x0ff00ff0 (arm_cond $ liftM3 O_QSUB   (arm_r 12 15) (arm_r 0 3) (arm_r 16 19))
  ,ARMOpcode32 [ARM_EXT_V5ExP] 0x01600050 0x0ff00ff0 (arm_cond $ liftM3 O_QDSUB  (arm_r 12 15) (arm_r 0 3) (arm_r 16 19))
  --, ARMOpcode32 [ARM_EXT_V1] 0x00000090 0x0e100090 [arm_const "str", arm_char1 6 6 's', arm_arr 5 5 ['h', 'b'], arm_c, arm_r 12 15, arm_s]
  --, ARMOpcode32 [ARM_EXT_V1] 0x00100090 0x0e100090 [arm_const "ldr", arm_char1 6 6 's', arm_arr 5 5 ['h', 'b'], arm_c, arm_r 12 15, arm_s]
  ,ARMOpcode32 [ARM_EXT_V1] 0x00000000 0x0de00000 (arm_cond $ liftM4 O_AND (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x00200000 0x0de00000 (arm_cond $ liftM4 O_EOR (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x00400000 0x0de00000 (arm_cond $ liftM4 O_SUB (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x00600000 0x0de00000 (arm_cond $ liftM4 O_RSB (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x00800000 0x0de00000 (arm_cond $ liftM4 O_ADD (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x00a00000 0x0de00000 (arm_cond $ liftM4 O_ADC (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  --,ARMOpcode32 [ARM_EXT_V1] 0x00c00000 0x0de00000 (arm_cond $ liftM4 O_SBC (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x00e00000 0x0de00000 (arm_cond $ liftM4 O_RSC (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  --, ARMOpcode32 [ARM_EXT_V3] 0x0120f000 0x0db0f000 [arm_const "msr", arm_c, arm_arr 22 22 ['S', 'C'], arm_const "PSR", arm_C, arm_o]
  --, ARMOpcode32 [ARM_EXT_V3] 0x010f0000 0x0fbf0fff [arm_const "mrs", arm_c, arm_r 12 15, arm_arr 22 22 ['S', 'C'], arm_const "PSR"]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01000000 0x0de00000 [arm_const "tst", arm_p, arm_c, arm_r 16 19, arm_o]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01200000 0x0de00000 [arm_const "teq", arm_p, arm_c, arm_r 16 19, arm_o]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01400000 0x0de00000 [arm_const "cmp", arm_p, arm_c, arm_r 16 19, arm_o]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01600000 0x0de00000 [arm_const "cmn", arm_p, arm_c, arm_r 16 19, arm_o]
  ,ARMOpcode32 [ARM_EXT_V1] 0x01800000 0x0de00000 (arm_cond $ liftM4 O_ORR (arm_bool 20) (arm_r 12 15) (arm_r 16 19) arm_o)
  ,ARMOpcode32 [ARM_EXT_V1] 0x03a00000 0x0fef0000 (arm_cond $ liftM3 O_MOV (arm_bool 20) (arm_r 12 15) arm_o)--, ARMOpcode32 [ARM_EXT_V1] 0x03a00000 0x0fef0000 [arm_const "mov", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_o]
  --,ARMOpcode32 [ARM_EXT_V1] 0x01a00000 0x0def0ff0 (arm_cond $ liftM3 O_MOV (arm_bool 20) (arm_r 12 15) (arm_r 0 3)) --, ARMOpcode32 [ARM_EXT_V1] 0x01a00000 0x0def0ff0 [arm_const "mov", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_r 0 3]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01a00000 0x0def0060 [arm_const "lsl", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_q]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01a00020 0x0def0060 [arm_const "lsr", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_q]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01a00040 0x0def0060 [arm_const "asr", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_q]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01a00060 0x0def0ff0 [arm_const "rrx", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_r 0 3]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01a00060 0x0def0060 [arm_const "ror", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_q]
  --, ARMOpcode32 [ARM_EXT_V1] 0x01c00000 0x0de00000 [arm_const "bic", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_r 16 19, arm_o]
  ,ARMOpcode32 [ARM_EXT_V1] 0x01e00000 0x0de00000 (arm_cond $ liftM3 O_MVN (arm_bool 20) (arm_r 12 15) arm_o)--, ARMOpcode32 [ARM_EXT_V1] 0x01e00000 0x0de00000 [arm_const "mvn", arm_char1 20 20 's', arm_c, arm_r 12 15, arm_o]
  --, ARMOpcode32 [ARM_EXT_V1] 0x052d0004 0x0fff0fff [arm_const "str", arm_c, arm_r 12 15, arm_a]
  --, ARMOpcode32 [ARM_EXT_V1] 0x04000000 0x0e100000 [arm_const "str", arm_char1 22 22 'b', arm_t, arm_c, arm_r 12 15, arm_a]
  --, ARMOpcode32 [ARM_EXT_V1] 0x06000000 0x0e100ff0 [arm_const "str", arm_char1 22 22 'b', arm_t, arm_c, arm_r 12 15, arm_a]
  --, ARMOpcode32 [ARM_EXT_V1] 0x04000000 0x0c100010 [arm_const "str", arm_char1 22 22 'b', arm_t, arm_c, arm_r 12 15, arm_a]
  --, ARMOpcode32 [ARM_EXT_V1] 0x06000010 0x0e000010 [arm_const "undefined"]
  --, ARMOpcode32 [ARM_EXT_V1] 0x049d0004 0x0fff0fff [arm_const "ldr", arm_c, arm_r 12 15, arm_a]
  --, ARMOpcode32 [ARM_EXT_V1] 0x04100000 0x0c100000 [arm_const "ldr", arm_char1 22 22 'b', arm_t, arm_c, arm_r 12 15, arm_a]
  --, ARMOpcode32 [ARM_EXT_V1] 0x092d0000 0x0fff0000 [arm_const "push", arm_c, arm_m]
  --, ARMOpcode32 [ARM_EXT_V1] 0x08800000 0x0ff00000 [arm_const "stm", arm_c, arm_r 16 19, arm_char1 21 21 '!', arm_m, arm_char1 22 22 '^']
  --, ARMOpcode32 [ARM_EXT_V1] 0x08000000 0x0e100000 [arm_const "stm", arm_arr 23 23 ['i', 'd'], arm_arr 24 24 ['b', 'a'], arm_c, arm_r 16 19, arm_char1 21 21 '!', arm_m, arm_char1 22 22 '^']
  --, ARMOpcode32 [ARM_EXT_V1] 0x08bd0000 0x0fff0000 [arm_const "pop", arm_c, arm_m]
  --, ARMOpcode32 [ARM_EXT_V1] 0x08900000 0x0f900000 [arm_const "ldm", arm_c, arm_r 16 19, arm_char1 21 21 '!', arm_m, arm_char1 22 22 '^']
  --, ARMOpcode32 [ARM_EXT_V1] 0x08100000 0x0e100000 [arm_const "ldm", arm_arr 23 23 ['i', 'd'], arm_arr 24 24 ['b', 'a'], arm_c, arm_r 16 19, arm_char1 21 21 '!', arm_m, arm_char1 22 22 '^']
  ,ARMOpcode32 [ARM_EXT_V1] 0x0a000000 0x0e000000 (arm_cond $ liftM2 O_B (arm_bool 24) arm_b)--, ARMOpcode32 [ARM_EXT_V1] 0x0a000000 0x0e000000 [arm_const "b", arm_char1 24 24 'l', arm_c, arm_b]
  --, ARMOpcode32 [ARM_EXT_V1] 0x0f000000 0x0f000000 [arm_const "svc", arm_c, arm_x 0 23] -- does this belong?
  --, ARMOpcode32 [ARM_EXT_V1] 0x00000000 0x00000000 [arm_const "undefined instruction", arm_x 0 31]  
  ]

armOpcodeMatches :: Word32 -> ARMOpcode32 -> Bool
armOpcodeMatches x (ARMOpcode32 _ v m _) = x .&. m == v 

armDecodeOp :: Word32 -> ARMState -> ARMOpcode32 -> ARMInstruction
armDecodeOp x s (ARMOpcode32 _ _ _ d) = d (s, x)

armDecode :: (Word32, Word32) -> Maybe ARMInstruction
armDecode (a, i) = fmap (armDecodeOp i (ARMState a)) . find (armOpcodeMatches i) $ armOpcodes
  
main = mapM_ print . map armDecode $
                             zip [0x2000,0x2004..] [0xE59D0000,
                                                    0xE28D1004,
                                                    0xE2804001,
                                                    0xE0812104,
                                                    0xE3CDD007,
                                                    0xE1A03002,
                                                    0xE4934004,
                                                    0xE3540000,
                                                    0x1AFFFFFC,
                                                    0xE59FC018,
                                                    0xE08FC00C,
                                                    0xE59CC000,
                                                    0xE12FFF3C,
                                                    0xE59FC00C,
                                                    0xE08FC00C,
                                                    0xE59CC000,
                                                    0xE12FFF1C,
                                                    0x000B2FD0,
                                                    0x000B2FC4,
                                                    0xE52DC004,
                                                    0xE59FC00C,
                                                    0xE79FC00C,
                                                    0xE52DC004,
                                                    0xE59FC004,
                                                    0xE79FF00C,
                                                    0x000B3748,
                                                    0x000B38F0,
                                                    0xE59FC000,
                                                    0xE79FF00C,
                                                    0x000B38E4,
                                                    0xE92D4080,
                                                    0xE28D7000,
                                                    0xE24DD004,
                                                    0xE58D0000,
                                                    0xE59D2000,
                                                    0xE3A03001,
                                                    0xE5823000,
                                                    0xE247D000,
                                                    0xE8BD8080,
                                                    0xE92D4080,
                                                    0xE28D7000,
                                                    0xE24DD008,
                                                    0xE58D0000,
                                                    0xE59D3000,
                                                    0xE58D3004,
                                                    0xE59D3004,
                                                    0xE593C004,
                                                    0xE59F3030,
                                                    0xE08F3003,
                                                    0xE1A00003,
                                                    0xE59D1000,
                                                    0xE59D2000,
                                                    0xE12FFF3C,
                                                    0xE1A03000,
                                                    0xE3530000,
                                                    0x0A000002,
                                                    0xE59D2004,
                                                    0xE3E03000,
                                                    0xE5823000,
                                                    0xE247D000,
                                                    0xE8BD8080,
                                                    0xFFFFFFB0,
                                                    0xE92D4090,
                                                    0xE28D7004,
                                                    0xE24DD014,
                                                    0xE58D0008,
                                                    0xE58D1004,
                                                    0xE3A03000,
                                                    0xE58D300C,
                                                    0xE59D3008,
                                                    0xE58D3010,
                                                    0xE28D200C,
                                                    0xE28DC00C,
                                                    0xE59D4008,
                                                    0xE59F3074,
                                                    0xE08F3003,
                                                    0xE1A00003,
                                                    0xE1A01002,
                                                    0xE1A0200C,
                                                    0xE12FFF34,
                                                    0xE1A03000,
                                                    0xE3530000,
                                                    0x0A000002,
                                                    0xE3E03000,
                                                    0xE58D3000,
                                                    0xEA00000E,
                                                    0xE28D300C,
                                                    0xE59D2004,
                                                    0xE1A00003,
                                                    0xE12FFF32,
                                                    0xE59D300C,
                                                    0xE3530000] -- -}