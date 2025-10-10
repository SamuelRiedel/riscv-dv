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
    if (format == CMPP_FORMAT) {
      // rlist can be anything between 4 and 15. 0-3 are reserved for future use.
      rlist inside {[4:15]};
    }
    if (format == CMMV_FORMAT) {
      // Always has rs1 and rs2 and they must be different
      rs1 != rs2;
      // Those instructions use a special encoding, only S0, S1, S2-S7 are allowed
      // which correspond to x8, x9, x18-x23, so the actual registers used are
      // {r1sc[2:1]>0,r1sc[2:1]==0,r1sc[2:0]};
      // So for registers beyond x16 we prepend 0x10 to the three LSB
      // For the registers x8 and x9 we prepend 0x01 to the three LSB
      rs1 inside {S0, S1, [S2:S7]};
      rs2 inside {S0, S1, [S2:S7]};
    }
  }

  // TODO? Where is imm tied to zero somewhere???
  // constraint imm_c {
  //   if (format == CMPP_FORMAT) {
  //     // Within this format, the immediate depends on whether it's a PUSH or POP
  //     if (instr_name == CM_PUSH) {
  //       imm inside {-16, -32, -48, -64};
  //       // --- All PUSH-related constraints go here ---
  //       // (rlist inside {4, 5, 6, 7})   -> imm inside {-16, -32, -48, -64};
  //       // (rlist inside {8, 9, 10, 11})  -> imm inside {-32, -48, -64, -80};
  //       // (rlist inside {12, 13, 14}) -> imm inside {-48, -64, -80, -96};
  //       // (rlist == 15)                -> imm inside {-64, -80, -96, -112};
  //     } else {
  //       imm inside {16, 32, 48, 64};
  //       // --- All POP-related constraints go here (handles instr_name != CM_PUSH) ---
  //       // (rlist inside {4, 5, 6, 7})   -> imm inside {16, 32, 48, 64};
  //       // (rlist inside {8, 9, 10, 11})  -> imm inside {32, 48, 64, 80};
  //       // (rlist inside {12, 13, 14}) -> imm inside {48, 64, 80, 96};
  //       // (rlist == 15)                -> imm inside {64, 80, 96, 112};
  //     }
  //   }
  // }

  `uvm_object_utils(riscv_zcmp_instr)

  function new(string name = "");
    super.new(name);
    rs1 = S0;
    rs2 = S0;
    rlist = 4;
    is_compressed = 1'b1;
  endfunction : new

  virtual function void set_imm_len();
    if (format == CMPP_FORMAT) begin
      imm_len = 2;
    end
  endfunction : set_imm_len

  // Overwrite get_imm to return the immediate string fitting the rlist
  // TODO, this is a hack because the random constraints don't work yet
  virtual function int get_imm_val();
    int options_q[$]; // A queue to hold the 4 valid integer options
    // Use a case statement to select the correct set of 4 values.
    case (rlist)
      4, 5, 6, 7:   options_q = '{16, 32, 48, 64};
      8, 9, 10, 11: options_q = '{32, 48, 64, 80};
      12, 13, 14:  options_q = '{48, 64, 80, 96};
      15:           options_q = '{64, 80, 96, 112};
      default: options_q = '{};
    endcase
    // Randomly select one value from the chosen set.
    // This code runs after one of the sets above has been chosen.
    if (options_q.size() == 0) begin
      // This case will be hit if the rlist was an unsupported value.
      `uvm_error("get_imm", $sformatf("Unsupported rlist value: %0d for instr %s",
                                      rlist, instr_name.name()));
      return 0; // Return a default value on error.
    end else begin
      // int rand_idx     = $urandom_range(options_q.size() - 1);
      int rand_idx     = 0; // TODO: Hardcode to zero because we need to have a constant value
      int selected_imm = options_q[rand_idx];
      selected_imm = instr_name == CM_PUSH ? -selected_imm : selected_imm;
      return selected_imm;
    end
  endfunction

  // Overwrite get_imm to return the immediate string fitting the rlist
  // TODO, this is a hack because the random constraints don't work yet
  virtual function string get_imm();
    int options_q[$]; // A queue to hold the 4 valid integer options
    // Use a case statement to select the correct set of 4 values.
    case (rlist)
      4, 5, 6, 7:   options_q = '{16, 32, 48, 64};
      8, 9, 10, 11: options_q = '{32, 48, 64, 80};
      12, 13, 14:  options_q = '{48, 64, 80, 96};
      15:           options_q = '{64, 80, 96, 112};
      default: options_q = '{};
    endcase
    // Randomly select one value from the chosen set.
    // This code runs after one of the sets above has been chosen.
    if (options_q.size() == 0) begin
      // This case will be hit if the rlist was an unsupported value.
      `uvm_error("get_imm", $sformatf("Unsupported rlist value: %0d for instr %s",
                                      rlist, instr_name.name()));
      return "0"; // Return a default value on error.
    end else begin
      // int rand_idx     = $urandom_range(options_q.size() - 1);
      int rand_idx     = 0; // TODO: Hardcode to zero because we need to have a constant value
      int selected_imm = options_q[rand_idx];
      selected_imm = instr_name == CM_PUSH ? -selected_imm : selected_imm;
      return $sformatf("%0d", selected_imm);
    end
  endfunction

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
        has_rlist = 1'b1;
      end
    endcase
  endfunction

  // Convert the instruction to assembly code
  virtual function string convert2asm(string prefix = "");
    string asm_str;
    asm_str = format_string(get_instr_name(), MAX_INSTR_STR_LEN);
    case(format)
      CMMV_FORMAT:
        asm_str = $sformatf("%0s %0s, %0s", asm_str, rs1.name(), rs2.name());
      CMPP_FORMAT: begin
        asm_str = $sformatf("%0s %0s, %0s", asm_str, get_rlist(), get_imm());
      end
      default: `uvm_info(`gfn, $sformatf("Unsupported format %0s", format.name()), UVM_LOW)
    endcase

    if (comment != "")
      asm_str = {asm_str, " #",comment};
    asm_str = {asm_str, " # ZCMP instruction cm. cm_ "};
    return asm_str.tolower();
  endfunction : convert2asm

  // Convert the instruction to binary code
  virtual function string convert2bin(string prefix = "");
    string binary;
    `uvm_info(`gfn, $sformatf("ZCMP %0s", instr_name), UVM_LOW)
    case (instr_name) inside
      CM_PUSH:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), rlist, imm[1:0], get_c_opcode()});
      CM_POP:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), rlist, imm[1:0], get_c_opcode()});
      CM_POPRETZ:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), rlist, imm[1:0], get_c_opcode()});
      CM_POPRET:
        binary = $sformatf("0x%4h", {get_func6(), get_func2(), rlist, imm[1:0], get_c_opcode()});
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
      CM_MVSA01  : get_func6 = 6'b101011;
      CM_MVA01S  : get_func6 = 6'b101011;
      default : `uvm_fatal(`gfn, $sformatf("Unsupported instruction %0s", instr_name.name()))
    endcase
  endfunction : get_func6

  virtual function bit [1:0] get_func2();
    case (instr_name) inside
      CM_PUSH    : get_func2 = 2'b00;
      CM_POP     : get_func2 = 2'b10;
      CM_POPRETZ : get_func2 = 2'b00;
      CM_POPRET  : get_func2 = 2'b10;
      CM_MVSA01  : get_func2 = 2'b01;
      CM_MVA01S  : get_func2 = 2'b11;
      default : `uvm_fatal(`gfn, $sformatf("Unsupported instruction %0s", instr_name.name()))
    endcase
  endfunction : get_func2

  virtual function bit is_supported(riscv_instr_gen_config cfg);
    `uvm_info(`gfn, "ZCMP Check supported", UVM_LOW)
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
        // rlist = get_gpr(operands[1]);
        // rs1_value = get_gpr_state(operands[1]);
      end
      default: ;
    endcase
    super.update_src_regs(operands);
  endfunction : update_src_regs

endclass : riscv_zcmp_instr;
