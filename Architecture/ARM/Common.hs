module Architecture.ARM.Common where

import Data.Word
import Data.Int

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

data ARMRegister = R0 | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 
                 | R9 | R10 | R11 | R12 | SP | LR | PC
  deriving (Show, Read, Eq, Enum)

data ARMShift = S_LSL | S_LSR | S_ASR | S_ROR
  deriving (Show, Read, Eq, Enum)

data ARMCondition = EQ | NE | CS | CC | MI | PL | VS | VC
                  | HI | LS | GE | LT | GT | LE | AL | UND
  deriving (Show, Read, Eq, Enum)

data ARMStatusRegister = CPSR | SPSR
  deriving (Show, Read, Eq, Enum)

data ARMEndian = Big | Little
  deriving (Show, Read, Eq, Enum)

data Nybble = High | Low
  deriving (Show, Read, Eq, Enum)

data Width = Byte | HalfWord | Word | DoubleWord
  deriving (Show, Read, Eq, Enum)

data ARMHint = SY | UN | ST | UNST | UK Word32 -- FIXME: should really prefix these consistently
  deriving (Show, Read, Eq)

data ARMMultipleDirection = Decrement | Increment
  deriving (Show, Read, Eq, Enum)
  
data ARMMultipleOrder = Before | After
  deriving (Show, Read, Eq, Enum)