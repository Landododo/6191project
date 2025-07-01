import CacheTypes;
import CacheHelpers;
import MainMemory;

// ReqStatus (defined in CacheTypes.ms) is used to keep track of the state of the current request
//typedef enum {
//    Ready,         // The cache is ready for a new request
//    Lookup,        // Issued a lookup to tag/data arrays
//    Writeback,     // In main memory access for dirty writeback
//    Fill           // In main memory access for requested data
//} ReqStatus;
//
// Possible flows:
//   HIT: Ready -> Lookup -> Ready
//   MISS, line is clean: Ready -> Lookup -> Fill
//   MISS, line is dirty: Ready -> Lookup -> Writeback -> Fill

// Cache SRAM Synonyms (defined in CacheTypes.ms)
// You may find the following type synonyms helpful to access the tag/data/status arrays
// typedef SRAMReq#(logCacheSets, CacheTag) TagReq;
// typedef SRAMReq#(logCacheSets, Line) DataReq;
// typedef SRAMReq#(logCacheSets, CacheStatus) StatusReq;

// TODO: Complete the implementation of DirectMappedCache
// NOTE: Implementing this module requires about 60 lines of additional code
// (~40-50 lines in rule tick, ~5-15 lines in method data, 1 line in method reqEnabled, 1 line in function isHit;
//  you may want to define an additional function to construct the word to write to the data array on a store,
//  combining the line's current data and the word/half-word/byte that is updated on an Sw/Sh/Sb operation)
module DirectMappedCache(MainMemory mainMem);
    // SRAM arrays. Note that, for a direct-mapped cache,
    // number of cache sets == number of cache lines
    SRAM#(logCacheSets, Line) dataArray;
    SRAM#(logCacheSets, CacheTag) tagArray;
    SRAM#(logCacheSets, CacheStatus) statusArray;
    
    // Registers for holding the current state of the cache and how far along
    // it is in processing a request.
    RegU#(MemReq) curReq;
    Reg#(ReqStatus) state(Ready);
    
    // Hit/miss counters
    Reg#(Word) hits(0);
    Reg#(Word) misses(0);
    input Maybe#(MemReq) req default = Invalid;
    
    // TODO return True if the cache can accept a new request (state is READY)
    method Bool reqEnabled = state == Ready  || (state == Lookup && isHit && isLoad(curReq.op));
    // TODO return True if the cache is in lookup and it is a hit
    function Bool isHit;
        return state == Lookup && getTag(curReq.addr) == fromMaybe(?,tagArray.data) && fromMaybe(?, statusArray.data) != NotValid;
    endfunction
    rule tick;
        if (state == Ready && isValid(req)) begin
            // TODO Your code here 
            state <= Lookup;
            let index = getIndex(fromMaybe(?,req).addr);
            TagReq tagRead =  TagReq{addr: index, write: False , data: ?};
            DataReq dataRead =  DataReq{addr: index, write: False, data: ?};
            StatusReq statusRead =  StatusReq{addr: index, write: False, data: ?};
            tagArray.req = Valid(tagRead);
            dataArray.req = Valid(dataRead);
            statusArray.req = Valid(statusRead);
            curReq <= fromMaybe(?,req);
        end else if (state == Lookup) begin
            // TODO Your code here
            //$display("in looku");
            let index = getIndex(curReq.addr);
            if (isHit && isLoad(curReq.op) && isValid(req)) begin
                //finishes current req and issues next request in same cycle
                hits <= hits + 1;
                let next = fromMaybe(?, req);
                curReq <= next;

                let idx = getIndex(next.addr);
                tagArray.req    = Valid(TagReq   { addr: idx, write: False, data:? });
                dataArray.req   = Valid(DataReq  { addr: idx, write: False, data:? });
                statusArray.req = Valid(StatusReq{ addr: idx, write: False, data:? });

            end else if (isHit) begin
                // mark cache as dirty on store and return value on read
                if (isStore(curReq.op)) begin
                StatusReq statusWrite = StatusReq{addr: index, write: True, data: Dirty};
                statusArray.req = Valid(statusWrite);
                let getLine = fromMaybe(?, dataArray.data);
                getLine[getWordOffset(curReq.addr)] = getStoreData(getLine[getWordOffset(curReq.addr)], curReq.data, getByteOffset(curReq.addr), curReq.op);
                dataArray.req = Valid(DataReq{addr: getIndex(curReq.addr), write: True, data: getLine});
                end
                state <= Ready;
                hits <= hits + 1;
                //$display("hitttt");
            end else begin
                // is a miss
                misses <= misses + 1;
                if(fromMaybe(?, statusArray.data) == Dirty) begin
                    //dirty miss so need to writeback
                    state <= Writeback;
                    mainMem.req = Valid(LineReq{
                    lineAddr: {fromMaybe(?, tagArray.data), getIndex(curReq.addr)}, 
                    write: True, 
                    data: fromMaybe(?, dataArray.data)
                });
                //$display("dirty mistt");
                end else begin
                    //clean miss
                    state <= Fill;
                    mainMem.req = Valid(LineReq{
                    lineAddr: getLineAddr(curReq.addr), 
                    write: False, 
                    data: ?
                    });
                    //$display("cleam isnts");
                end
            end
        end else if (state == Writeback && mainMem.reqEnabled) begin
            // TODO Your code here
            //memory is ready and is in writeback so now can get new stuff loaded
            state <= Fill;
            mainMem.req = Valid(LineReq{
                lineAddr: getLineAddr(curReq.addr), 
                write: False, 
                data: ?
            });
        end else if (state == Fill && isValid(mainMem.data)) begin
            // Now is in fill state and has valid memory
            state <= Ready;
            Line newData = fromMaybe(?, mainMem.data);
            let index = getIndex(curReq.addr);
            TagReq tagRead =  TagReq{addr: index, write: True, data: getTag(curReq.addr)};
            tagArray.req = Valid(tagRead);
            let wordOffset = getWordOffset(curReq.addr);
            let byteOffset = getByteOffset(curReq.addr);
            if (isLoad(curReq.op)) begin
                let arrayofData = fromMaybe(?, mainMem.data);
                DataReq cacheUpdate = DataReq{addr: index, write:True, data: arrayofData};
                dataArray.req = Valid(cacheUpdate);
                StatusReq statusRead =  StatusReq{addr: index, write: True, data: Clean};
                statusArray.req = Valid(statusRead);
            end else begin
                //must be a store
                let importantData = getStoreData(fromMaybe(?,mainMem.data)[wordOffset], curReq.data, byteOffset, curReq.op); //load and then modify so dirty
                let arrayofData = fromMaybe(?, mainMem.data);
                arrayofData[wordOffset] = importantData;
                //$display(importantData);
                DataReq dataStore = DataReq{addr: index, write: True, data: arrayofData};
                dataArray.req = Valid(dataStore);
                StatusReq statusRead =  StatusReq{addr: index, write: True, data: Dirty};
                statusArray.req = Valid(statusRead);
            end
        end
    endrule
    method Maybe#(Word) data;
        // This method should return a Valid output in only two cases:
        // 1. On a load hit (it is a hit, and isLoad(curReq.op)).
        // 2. On a fill for a load request (we're in the Fill state,
        //    mainMem.data is valid, and isLoad(curReq.op)).
        // In all other cases, the output should be Invalid.
        //
        // This method should handle sub-word loads, producing the right 32-bit
        // output to store on a register from the word read from the cache.
        //
        // NOTE: You should be checking the above conditions explicitly in
        //    THIS method so you can return data as soon as possible.
        //    DO NOT place your output into a register in the rule and then
        //    simply return that register here.

        // This function should take about 5-15 lines of code to implement.
        // TODO Your code here.
        if (isLoad(curReq.op) && isHit) begin
            let index = getIndex(curReq.addr);
            let wordOffset = getWordOffset(curReq.addr);
            let byteOffset = getByteOffset(curReq.addr);
            let newData = fromMaybe(?, dataArray.data);
            let wordData = newData[wordOffset];
            return Valid(getLoadData(wordData, byteOffset, curReq.op));
        end else if (state == Fill && isValid(mainMem.data) && isLoad(curReq.op)) begin
            let index = getIndex(curReq.addr);
            let wordOffset = getWordOffset(curReq.addr);
            let byteOffset = getByteOffset(curReq.addr);
            let newData = fromMaybe(?, mainMem.data);
            let wordData = newData[wordOffset];
            return Valid(getLoadData(wordData, byteOffset, curReq.op));
        end else begin
            return Invalid;
        end
    endmethod

    method Bit#(32) getHits = hits;
    method Bit#(32) getMisses = misses;
endmodule