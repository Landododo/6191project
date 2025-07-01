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

// TODO: Complete the implementation of TwoWayCache
// NOTE: Implementing this module requires about 20 new lines of code from DirectMappedCache
module TwoWayCache(MainMemory mainMem);
    // SRAM arrays, one element per way (e.g., dataArrays[0] is the data array of way 0).
    Vector#(2, SRAM#(logCacheSets, Line)) dataArrays;
    Vector#(2, SRAM#(logCacheSets, CacheTag)) tagArrays;
    Vector#(2, SRAM#(logCacheSets, CacheStatus)) statusArrays;

    // LRU bits, one per set. We implement it as registers instead of an SRAM
    // array, because with small caches this is just a few bits (e.g., 64), and
    // SRAMs make sense only for larger memories. This also makes the code
    // simpler, and will make the cache easier to pipeline in the future.
    Vector#(cacheSets, RegU#(Bit#(1))) lru;

    // Registers for holding the current state of the cache and how far along
    // it is in processing a request.
    RegU#(MemReq) curReq;
    Reg#(ReqStatus) state(Ready);
 
    // Hit/miss counters
    Reg#(Word) hits(0);
    Reg#(Word) misses(0);
    
    input Maybe#(MemReq) req default = Invalid;
    
    // TODO return True if the cache can accept a new request
    method Bool reqEnabled = state == Ready;

    // TODO return True if the cache is in lookup and it is a hit in this way.
    function Bool isHit(Integer way);
        return state == Lookup && getTag(curReq.addr) == fromMaybe(?, tagArrays[way].data) && fromMaybe(?, statusArrays[way].data) != NotValid;
    endfunction

    rule tick;
        if (state == Ready && isValid(req)) begin
            // TODO Your code here 
            state <= Lookup;
            let index = getIndex(fromMaybe(?,req).addr);
            TagReq tagRead = TagReq{addr: index, write: False , data: ?};
            DataReq dataRead = DataReq{addr: index, write: False, data: ?};
            StatusReq statusRead = StatusReq{addr: index, write: False, data: ?};
            tagArrays[0].req = Valid(tagRead);
            dataArrays[0].req = Valid(dataRead);
            statusArrays[0].req = Valid(statusRead);
            tagArrays[1].req = Valid(tagRead);
            dataArrays[1].req = Valid(dataRead);
            statusArrays[1].req = Valid(statusRead);
            curReq <= fromMaybe(?,req);
        end else if (state == Lookup) begin
            // TODO Your code here 
            let index = getIndex(curReq.addr);
            if (isHit(1)) begin
                // mark cache as dirty on store and return value on read
                if (isStore(curReq.op)) begin
                StatusReq statusWrite = StatusReq{addr: index, write: True, data: Dirty};
                statusArrays[1].req = Valid(statusWrite);
                let getLine = fromMaybe(?, dataArrays[1].data);
                getLine[getWordOffset(curReq.addr)] = getStoreData(getLine[getWordOffset(curReq.addr)], curReq.data, getByteOffset(curReq.addr), curReq.op);
                dataArrays[1].req = Valid(DataReq{addr: getIndex(curReq.addr), write: True, data: getLine});
                end 
                state <= Ready;
                hits <= hits + 1;
                $display("hitttt");
                lru[index] <=0;
            end else if (isHit(0)) begin
                if (isStore(curReq.op)) begin
                    StatusReq statusWrite = StatusReq{addr: index, write: True, data: Dirty};
                    statusArrays[0].req = Valid(statusWrite);
                    let getLine = fromMaybe(?, dataArrays[0].data);
                    getLine[getWordOffset(curReq.addr)] = getStoreData(getLine[getWordOffset(curReq.addr)], curReq.data, getByteOffset(curReq.addr), curReq.op);
                    dataArrays[0].req = Valid(DataReq{addr: getIndex(curReq.addr), write: True, data: getLine});
                    end 
                    state <= Ready;
                    hits <= hits + 1;
                    lru[index] <= 1;
            end else begin
                // is a miss
                misses <= misses + 1;
                //let index = getIndex(curReq.addr);
                if(fromMaybe(?, statusArrays[lru[index]].data) == Dirty) begin
                    //dirty miss so need to writeback
                    state <= Writeback;
                    mainMem.req = Valid(LineReq{
                    lineAddr: {fromMaybe(?, tagArrays[lru[index]].data), getIndex(curReq.addr)}, 
                    write: True, 
                    data: fromMaybe(?, dataArrays[lru[index]].data)
                });
                $display("dirty mistt");
                end else begin
                    //clean miss
                    state <= Fill;
                    mainMem.req = Valid(LineReq{
                    lineAddr: getLineAddr(curReq.addr), 
                    write: False, 
                    data: ?
                    });
                    $display("cleam isnts");

                end
            end

        end else if (state == Writeback && mainMem.reqEnabled) begin
            // TODO Your code here 
            state <= Fill;
            mainMem.req = Valid(LineReq{
                lineAddr: getLineAddr(curReq.addr), 
                write: False, 
                data: ?
            });
        end else if (state == Fill && isValid(mainMem.data)) begin
            // TODO Your code here 
            state <= Ready;
            Line newData = fromMaybe(?, mainMem.data);
            let index = getIndex(curReq.addr);
            TagReq tagRead =  TagReq{addr: index, write: True, data: getTag(curReq.addr)};
            let leastUsed = lru[index];
            tagArrays[leastUsed].req = Valid(tagRead);
            let wordOffset = getWordOffset(curReq.addr);
            let byteOffset = getByteOffset(curReq.addr);
            if (isLoad(curReq.op)) begin
                let arrayofData = fromMaybe(?, mainMem.data);
                DataReq cacheUpdate = DataReq{addr: index, write:True, data: arrayofData};
                dataArrays[leastUsed].req = Valid(cacheUpdate);
                StatusReq statusRead =  StatusReq{addr: index, write: True, data: Clean};
                statusArrays[leastUsed].req = Valid(statusRead);

            end else begin
                //must be a store
                let importantData = getStoreData(fromMaybe(?,mainMem.data)[wordOffset], curReq.data, byteOffset, curReq.op); //load and then modify so dirty
                let arrayofData = fromMaybe(?, mainMem.data);
                arrayofData[wordOffset] = importantData;
                $display(importantData);
                DataReq dataStore = DataReq{addr: index, write: True, data: arrayofData};
                dataArrays[leastUsed].req = Valid(dataStore);
                StatusReq statusRead =  StatusReq{addr: index, write: True, data: Dirty};
                statusArrays[leastUsed].req = Valid(statusRead);
            end
            lru[index] <= ~lru[index];
        end
            
    endrule

    method Maybe#(Word) data;
        // This method should return a Valid output in only two cases:
        // 1. On a load hit (we're in the Lookup state, there's a hit, and
        //    isLoad(curReq.op)).
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
        // This function should take about 5-20 lines of code to implement.
        // TODO Your code here
	    if (isLoad(curReq.op) && isHit(0)) begin
            let index = getIndex(curReq.addr);
            let wordOffset = getWordOffset(curReq.addr);
            let byteOffset = getByteOffset(curReq.addr);
            let newData = fromMaybe(?, dataArrays[0].data);
            let wordData = newData[wordOffset];
            return Valid(getLoadData(wordData, byteOffset, curReq.op));
        end else if (isLoad(curReq.op) && isHit(1)) begin
            let index = getIndex(curReq.addr);
            let wordOffset = getWordOffset(curReq.addr);
            let byteOffset = getByteOffset(curReq.addr);
            let newData = fromMaybe(?, dataArrays[1].data);
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