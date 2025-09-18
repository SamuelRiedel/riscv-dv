/*
 * Copyright 2025 Google LLC
 * Copyright 2025 lowRISC CIC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

class riscv_zcmp_instr extends riscv_instr;

  constraint rvc_csr_c {
    // Registers specified by the three-bit rs1’, rs2’, and rd/rs1’
    if (format inside {CMMV_FORMAT, CMPP_FORMAT}) {
      // reuse rs1 for special rd'/rs1' randomize_gpr function makes sure
      // a reserved register is not used.
      if (has_rs1) {
        rs1 inside {[S0:A5]};
      }
      if (has_rs2) {
        rs2 inside {[S0:A5]};
      }
      // TODO urlist? Doens't need to be constrained. full range
    }
  }

  `uvm_object_utils(riscv_zcmp_instr)

  function new(string name = "");
    super.new(name);
    rs1 = S0;
    rs2 = S0;
    // TODO urlist?
    is_compressed = 1'b1;
  endfunction : new

  virtual function void set_imm_len();
    if (format == CMPP_FORMAT) begin
      imm_len = 2;
    end
  endfunction : set_imm_len

  virtual function void set_rand_mode();
    case (format) inside
      CMMV_FORMAT : begin
        has_rd = 1'b0;
        has_imm = 1'b0;
      end
      CMPP_FORMAT : begin
        has_rs1 = 1'b0;
        has_rs2 = 1'b0;
        has_rd = 1'b0;
        has_urlist = 1'b1;
      end
    endcase
  endfunction

  // Convert the instruction to assembly code
  virtual function string convert2asm(string prefix = "");
    string asm_str;
    asm_str = format_string(get_instr_name(), MAX_INSTR_STR_LEN);
    case(format)
      CMMV_FORMAT:
        asm_str = $sformatf("%0s%0s, %0s(%0s)", asm_str, rs1.name(), rs2.name());
      CMPP_FORMAT:
        asm_str = $sformatf("%0s%0s, %0s(%0s)", asm_str, get_urlist(), get_imm());
      default: `uvm_info(`gfn, $sformatf("Unsupported format %0s", format.name()), UVM_LOW)
    endcase

    if (comment != "")
      asm_str = {asm_str, " #",comment};
    return asm_str.tolower();
  endfunction : convert2asm

  // Convert the instruction to binary code
  virtual function string convert2bin(string prefix = "");
    string binary;
    case (instr_name) inside
      //`uvm_info(`gfn, $sformatf("rs1 = %0s, imm = %b,
      CM_PUSH:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), urlist, imm[1:0], get_c_opcode()});
      CM_POP:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), urlist, imm[1:0], get_c_opcode()});
      CM_POPRETZ:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), urlist, imm[1:0], get_c_opcode()});
      CM_POPRET:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), urlist, imm[1:0], get_c_opcode()});
      CM_MVA01S:
        binary = $sformatf("0x%4h", {get_func6(), get_c_gpr(rs1), get_func2(), get_c_gpr(rs2), get_c_opcode()});
      CM_MVSA01:
        binary = $sformatf("0x%4h", {get_func6(), get_c_gpr(rs1), get_func2(), get_c_gpr(rs2), get_c_opcode()});
      default : `uvm_fatal(`gfn, $sformatf("Unsupported instruction %0s", instr_name.name()))
    endcase
    return {prefix, binary};
  endfunction : convert2bin

  // Get opcode for zcmp instruction
  virtual function bit [1:0] get_c_opcode();
    case (instr_name) inside
      CM_PUSH, CM_POP, CM_POPRETZ, CM_POPRET, CM_MVA01S, CM_MVSA01 : get_c_opcode = 2'b10;
      default : `uvm_fatal(`gfn, $sformatf("Unsupported instruction %0s", instr_name.name()))
    endcase
  endfunction : get_c_opcode

  virtual function bit [5:0] get_func6();
    case (instr_name) inside
      CM_PUSH    : get_func6 = 6'b101110;
      CM_POP     : get_func6 = 6'b101110;
      CM_POPRETZ : get_func6 = 6'b101111;
      CM_POPRET  : get_func6 = 6'b101111;
      CM_MVA01S  : get_func6 = 6'b101011;
      CM_MVSA01  : get_func6 = 6'b101001;
      default : `uvm_fatal(`gfn, $sformatf("Unsupported instruction %0s", instr_name.name()))
    endcase
  endfunction : get_func6

  virtual function bit [1:0] get_func2();
    case (instr_name) inside
      CM_PUSH    : get_func2 = 2'b00;
      CM_POP     : get_func2 = 2'b10;
      CM_POPRETZ : get_func2 = 2'b00;
      CM_POPRET  : get_func2 = 2'b10;
      CM_MVA01S  : get_func2 = 2'b01;
      CM_MVSA01  : get_func2 = 2'b11;
      default : `uvm_fatal(`gfn, $sformatf("Unsupported instruction %0s", instr_name.name()))
    endcase
  endfunction : get_func2

  virtual function bit is_supported(riscv_instr_gen_config cfg);
    return (cfg.enable_zcmp_extension &&
           // RV32C, RV32Zbb, RV32Zba, M/Zmmul is prerequisites for this extension
          (RV32C inside {supported_isa} || RV64C inside {supported_isa}) &&
          (RV32ZCMP inside {supported_isa} || RV64ZCMP inside {supported_isa})   &&
           instr_name inside {
              CM_PUSH, CM_POP, CM_POPRET, CM_POPRETZ, CM_MVA01S, CM_MVSA01
           });
  endfunction : is_supported

  // For coverage
  // TODO together with the implementation in vendor/google_riscv-dv/src/isa/riscv_instr_cov.svh
  virtual function void update_src_regs(string operands[$]);
    case(format)
      CMMV_FORMAT: begin
        // rs1 = get_gpr(operands[0]);
        // rs1_value = get_gpr_state(operands[0]);
      end
      CMPP_FORMAT: begin
        // get_val(operands[2], imm);
        // urlist = get_gpr(operands[1]);
        // rs1_value = get_gpr_state(operands[1]);
      end
      default: ;
    endcase
    super.update_src_regs(operands);
  endfunction : update_src_regs

endclass : riscv_zcmp_instr;
