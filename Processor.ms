import ProcTypes;

import RegisterFile;
import Decode;
import Execute;

// MainMemory includes the MainMemory port
// and the SingleCycleMemory modules
import MainMemory;

// Exercise 3: Select which cache(s) to import
import DirectMappedCache;
import TwoWayCache;

// Types associated with the Fetch stage
typedef enum {
    Dequeue, // Consume instruction at the f2d output, if any
    Stall, // Do not consume instruction at f2d
    Redirect  // Redirect fetch to another PC, annulling any fetched instructions
} FetchAction;

typedef struct {
    FetchAction fetchAction;
    Word redirectPc;  // PC to fetch from, used only if fetchAction is Redirect
} FetchInput;


typedef struct {
    Word pc;
    Word inst;
} F2D;

typedef struct {
    Word pc;
    DecodedInst dInst;
    Word rVal1;
    Word rVal2;
    // Add anything you need
} D2E;

typedef struct {
    Word pc;
    IType iType;
    Maybe#(RIndx) dst;
    Word data;
    // Add anything you need
} E2W;


// Fetch stage, including pc and instruction memory/cache
// 
// See handout for the structure of the recommended Fetch stage. 
//
// Implementing this module is optional: you can place the fetch logic and
// iMem/iCache inside the processor instead. We recommend you use a separate
// module to ease debugging.
module Fetch;
    Reg#(Word) pc(0);

    // Execise 3: uncomment this declaration
    // Extra bit of state to deal with interaction between iCache misses and annulments
    // For more details, see handout, Part 3.2, final bulletpoint
    // Reg#(Bool) ignoreInstr(False);

    // Single-cycle Instruction Memory
    // Exercise 3: comment this declaration out
    //SingleCycleMemory iMem;
    
    // Line-based Main Memory to use with caches
    // Exercise 3: uncomment this declaration
    MainMemory iMem;

    // Exercise 3: choose which type of iCache to use
    DirectMappedCache iCache(iMem);
    Reg#(Bool) toIgnore(False);
    Reg#(Bool) waiting(False);
    
    //TwoWayCache iCache(iMem);

    input FetchInput in;

    // Exercise 3: Modify to use iCache instead
    method Maybe#(F2D) f2d = isValid(iCache.data) && !toIgnore?
        Valid(F2D{pc: pc, inst: fromMaybe(?, iCache.data)}) : Invalid;

    rule fetch;
        // Fetch instructions from iMem/iCache and update PC according to in.
        //////////////////////////
        // TODO: Your code here //
        if (iCache.reqEnabled) begin
            Word mux1 = in.fetchAction == Stall ? pc : pc + 4; //mux to select if pc or pc+4
            Word newpc = in.fetchAction == Redirect ? in.redirectPc : mux1; // new pc mux determining if propogate pc value or redirect
            iCache.req = Valid(MemReq{
                addr: newpc,
                op: Lw,
                data: ?
            });
            toIgnore <= False;
            pc <= newpc;
        end else if (in.fetchAction == Redirect) begin
            toIgnore <= True;
            pc <= in.redirectPc;
        end else begin
            Word mux1 = in.fetchAction == Stall ? pc : pc + 4; //mux to select if pc or pc+4
            Word newpc = in.fetchAction == Redirect ? in.redirectPc : mux1; // new pc mux determining if propogate pc value or redirect
            pc <= newpc;
        end
    endrule

    // Used only for pipeline debugging; you should not use this method
    // elsewhere in your code (assume the fetch stage can run ahead)
    method Word getPc = pc; 
endmodule


module Processor;
    Fetch fetch;

    RegisterFile rf;

    // Single-cycle data memory
    // Exercise 3: comment this declaration out
    //SingleCycleMemory dMem;

    // Line-based Main Memory to use with caches
    // Exercise 3: uncomment this declaration
    MainMemory dMem;

    // Exercise 3: choose which type of data cache to use
    // NOTE: The CacheWrapper#() type of the dCache is critical, as it is used
    // for detecting that the program has finished running
    //CacheWrapper#(DirectMappedCache) dCache(dMem);
    CacheWrapper#(TwoWayCache) dCache(dMem);

    // Pipeline Registers
    Reg#(Maybe#(D2E)) d2e(Invalid);
    Reg#(Maybe#(E2W)) e2w(Invalid);
    Reg#(Bool) started(False);  //indicates if past first instruction 

    // Performance counters
    // These are used in the processor rule for debugging help, by tracking the
    // cycles and instructions completed. They are not needed for correctness
    // and you may remove them, but doing so is unlikely to reduce cycle time.
    Reg#(Bit#(32)) cycle(0);
    Reg#(Bit#(32)) instrs(0);

    rule tick;
        //////////////////////
        // Debugging Helper //
        //////////////////////
        cycle <= cycle + 1;
        // Uncomment the code below to print pipeline state each cycle
        // begin
        //     $write("[%d] F|D|E|W PCs: ", cycle);
        //     $write("%x|", fetch.getPc);
        //     if (isValid(fetch.f2d)) $write("%x|", fromMaybe(?, fetch.f2d).pc); else $write("%8s|", "NOP");
        //     if (isValid(d2e)) $write("%x|", fromMaybe(?, d2e).pc); else $write("%8s|", "NOP");
        //     if (isValid(e2w)) $write("%x", fromMaybe(?, e2w).pc); else $write("%8s", "NOP");
        //     $display("  instrs: %d", instrs);
        //     //$display(fetch.waitingOnCache);
        // end

        /////////////////////
        // Writeback Stage //
        /////////////////////
        // Signals used by decode to handle data hazards
        RIndx dstW = 0;
        Maybe#(Word) dataW = Invalid;

        // Exercise 3:
        // Signal for dCache-induced stalls
        Bool dDataStall = False;
        if (isValid(e2w)) begin
            let e2w_v = fromMaybe(?, e2w);
            //////////////////////////
            // TODO: Your code here //
            //////////////////////////
            if (isValid(e2w_v.dst)) begin
                dstW = fromMaybe(?, e2w_v.dst);
                if (e2w_v.iType == LOAD) begin
                    if (isValid(dCache.data)) begin
                        rf.wr = Valid(RegWriteArgs{index: fromMaybe(?, e2w_v.dst), data: fromMaybe(?,dCache.data)});
                        dataW = dCache.data;
                        dDataStall = False;
                    end else dDataStall = True;
                end else begin
                    rf.wr = Valid(RegWriteArgs{index: fromMaybe(?, e2w_v.dst), data: e2w_v.data});
                    dataW = Valid(e2w_v.data);
                end
            end

            // Count every instruction that leaves the writeback stage
            // (for debugging help)
            instrs <= instrs + 1;

            // BEGIN: DO NOT REMOVE OR MODIFY THIS CODE
            // If unsupported instruction, stops simulation and print the state of the processor
            if (e2w_v.iType == Unsupported) begin
                $display("Reached unsupported instruction");
                $display("Dumping the state of the processor");
                $display("pc = 0x%x", e2w_v.pc);
                $display(rf.fshow);
                $display("Quitting simulation.");
                $finish;
            end
            // END: DO NOT REMOVE OR MODIFY THIS CODE
        end


        ///////////////////
        // Execute Stage //
        ///////////////////
        // Signals used to handle mispredictions
        Bool annul = False;
        Word redirectPc = ?;

        // Signals used by decode to handle data hazards
        RIndx dstE = 0;
        Maybe#(Word) dataE = Invalid;

        // Exercise 3:
        // Signal for dCache-induced stalls
        Bool dReqStall = False;
        if (isValid(d2e)) begin
            let d2e_v = fromMaybe(?, d2e);
            //////////////////////////
            // TODO: Your code here //
            //////////////////////////
            ExecInst result = execute(d2e_v.dInst, d2e_v.rVal1, d2e_v.rVal2, d2e_v.pc );
            let dest = result.dst;
            dstE = fromMaybe(?, dest);
            dataE = (result.iType == LOAD || !isValid(dest)) ? Invalid : Valid(result.data);
            if (result.nextPc != d2e_v.pc + 4) begin
                // nextpc doesn't match predicted pc
                annul = True;
                redirectPc = result.nextPc;
            end
            if (result.iType == STORE) begin
                // issure proper store mem req
                if (dCache.reqEnabled && !dReqStall) begin
                    dCache.req = Valid(MemReq{
                        op: result.memFunc, 
                        addr: result.addr, 
                        data: result.data
                    });
                    dReqStall = False;
                end else begin
                    dReqStall = True;
                end
                dest = Invalid;
            end else if (result.iType == LOAD) begin
                // isue proper load mem req
                if (dCache.reqEnabled && !dReqStall) begin
                    dCache.req = Valid(MemReq{
                        op: result.memFunc, 
                        addr: result.addr, 
                        data: ?
                    });
                    dReqStall = False;
                end else begin
                    dReqStall = True;
                end
            end 
            if (!dReqStall && !dDataStall) begin
                e2w <= Valid(E2W{
                    pc: d2e_v.pc,
                    iType: result.iType,
                    dst: dest,
                    data: result.data});
            end
            else if (!dDataStall) begin
                e2w <= Invalid; 
            end
        end else if (!dDataStall)begin
            e2w <= Invalid;
        end

        //////////////////
        // Decode Stage //
        //////////////////
        // Signal for decode stalls
        Bool hazardStall = False;
        FetchAction fetch_action = Stall;
        if (!dReqStall && !dDataStall) begin 
            if (annul) begin
                d2e <= Invalid;
                fetch_action = Redirect;
            end else if (isValid(fetch.f2d)) begin
                F2D f2d_v = fromMaybe(?, fetch.f2d);
                DecodedInst dInst = decode(f2d_v.inst);
                let r1 = dInst.src1;
                let r2 = dInst.src2;
                hazardStall = (!isValid(dataE) && (dstE == r1 || dstE == r2) && dstE != 0);
                Word rVal1 = 0;
                Word rVal2 = 0;

                if (isValid(dataE) &&  dstE == r1 &&  dstE != 0) rVal1 = fromMaybe(?, dataE);
                else 
                if (isValid(dataW) && dstW == r1 && dstW !=0) rVal1 = fromMaybe(?,dataW);
                else rVal1 = rf.rd1(r1);

                if (isValid(dataE) &&  dstE == r2 &&  dstE != 0) rVal2 = fromMaybe(?,dataE);
                else 
                if (isValid(dataW) && dstW == r2 && dstW !=0) rVal2 = fromMaybe(?,dataW);
                else rVal2 = rf.rd2(r2);

                if (!hazardStall) begin
                    d2e <= Valid(D2E{pc: f2d_v.pc, dInst: dInst, rVal1: rVal1, rVal2: rVal2});
                    fetch_action = Dequeue;
                end else begin
                    d2e <= Invalid;
                end
            end else begin
                d2e <= Invalid;
            end
        end

       

        ///////////////////////
        // Drive fetch stage //
        ///////////////////////

        // TODO: Change to implement correct stall/annul behavior
        // if (!started && !dDataStall && !dReqStall) begin
        //     fetch.in = FetchInput{fetchAction: Stall, redirectPc: fetch.getPc};
        //     started <= True;
        // end else if (!fetch.waitingOnCache && !dDataStall && !dReqStall) begin
        //     let fetchAct = annul ? Redirect :
        //         hazardStall ? Stall :
        //         Dequeue;
        //     let redirectPC = annul ? redirectPc : fetch.getPc;
        //     fetch.in = FetchInput{fetchAction: fetchAct, redirectPc: redirectPC};
        // end else fetch.in = FetchInput{fetchAction: Stall, redirectPc: fetch.getPc};
        fetch.in = FetchInput{fetchAction: fetch_action, redirectPc: redirectPc};
    endrule
    // fetch.in = FetchInput{fetchAction: fetch_action, redirectPc: redirectPc};
    // endrule
    // This method gives a non-trivial output that depends on execution so that
    // synth doesn't optimize out the whole processor :)
    method Word getPc = fetch.getPc;
endmodule
