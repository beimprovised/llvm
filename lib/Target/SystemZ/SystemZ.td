//===-- SystemZ.td - Describe the SystemZ target machine -----*- tblgen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Target-independent interfaces which we are implementing
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"

//===----------------------------------------------------------------------===//
// SystemZ subtargets scheduling models.
//===----------------------------------------------------------------------===//
include "SystemZSchedule.td"

//===----------------------------------------------------------------------===//
// SystemZ supported processors and features
//===----------------------------------------------------------------------===//

include "SystemZProcessors.td"

//===----------------------------------------------------------------------===//
// Register file description
//===----------------------------------------------------------------------===//

include "SystemZRegisterInfo.td"

//===----------------------------------------------------------------------===//
// Calling convention description
//===----------------------------------------------------------------------===//

include "SystemZCallingConv.td"

//===----------------------------------------------------------------------===//
// Instruction descriptions
//===----------------------------------------------------------------------===//

include "SystemZOperators.td"
include "SystemZOperands.td"
include "SystemZPatterns.td"
include "SystemZInstrFormats.td"
include "SystemZInstrInfo.td"
include "SystemZInstrVector.td"
include "SystemZInstrFP.td"

def SystemZInstrInfo : InstrInfo {}

//===----------------------------------------------------------------------===//
// Assembly parser
//===----------------------------------------------------------------------===//

def SystemZAsmParser : AsmParser {
  let ShouldEmitMatchRegisterName = 0;
}

//===----------------------------------------------------------------------===//
// Top-level target declaration
//===----------------------------------------------------------------------===//

def SystemZ : Target {
  let InstructionSet = SystemZInstrInfo;
  let AssemblyParsers = [SystemZAsmParser];
}
