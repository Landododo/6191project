import CacheTypes;

////////////////////////////////////////
// Address Helper Functions //
// NOTE: Each of these functions can be implemented with a single line.
// Use the constants logCacheSets and logWordsPerLine, defined in CacheTypes.ms
////////////////////////////////////////


// Extract the Cache Line Byte Offset from a given memory address
function ByteOffset getByteOffset(Word byteAddress);
    // TODO: Implement this in Exercise 1.
    //Vector#(ByteOffset, Word) ret = takeAt(0, byteAddress);
     return byteAddress[1:0];
endfunction

// Extract the Cache Line Index from a given memory address
function CacheIndex getIndex(Word byteAddress);
    // TODO: Implement this in Exercise 1.
    return byteAddress[logCacheSets + 1 + logWordsPerLine:2+logWordsPerLine]; 

endfunction


// Extract the Cache Line Tag from a given memory address
function CacheTag getTag(Word byteAddress);
    // TODO: Implement this in Exercise 1.
    return byteAddress[31:2 + logWordsPerLine + logCacheSets];
endfunction


// Extract the Cache Line Word Offset from a given memory address
function WordOffset getWordOffset(Word byteAddress);
    // TODO: Implement this in Exercise 1.
    return byteAddress[logWordsPerLine + 1:2];
endfunction


// Extract the line address (tag + index) from a given memory address
function LineAddr getLineAddr(Word byteAddress);
    // TODO: Implement this in Exercise 1.
    return byteAddress[31:2+logWordsPerLine]; 
endfunction


////////////////////////////////////////
// Memory Helper Functions //
////////////////////////////////////////

// Load the correct word (or halfword or byte based on the given memory 
// operation `op`) from `word`. If `op` is a subword load operation, use 
// memory address in `byteOffset` to extract the correct bytes of data.
function Word getLoadData(Word word, Bit#(2) byteOffset, MemFunc op);
    // TODO: Implement this in Exercise 2.
    Word data = 0;
    case(op)
        Lw: data = word;
        Lh: data = byteOffset == 2 ? signExtend(word[31:16]) : signExtend(word[15:0]);
        Lhu: data = byteOffset == 2 ? zeroExtend(word[31:16]) : zeroExtend(word[15:0]);
        Lb: begin
            case(byteOffset)
                0 : data = signExtend(word[7:0]);
                1 : data = signExtend(word[15:8]);
                2 : data = signExtend(word[23:16]);
                3 : data = signExtend(word[31:24]);
            endcase
        end
        Lbu: begin
            case(byteOffset)
                0 : data = zeroExtend(word[7:0]);
                1 : data = zeroExtend(word[15:8]);
                2 : data = zeroExtend(word[23:16]);
                3 : data = zeroExtend(word[31:24]);
            endcase
        end
    default: data = 0;
    endcase
    return data;
    
endfunction


// Store the new data `newData` in word `currentData`. If `op` is a subword 
// store operation, store the correct bytes of data from `newData` in the 
// correct bytes of word `currentData`. Return modified word.
function Word getStoreData(Word currentData, Word newData, Bit#(2) byteOffset, MemFunc op);
    // TODO: Implement this in Exercise 2.
    case(op)
    //update currentData based on newData and the memory op and byteOffset
        Sw: currentData = newData;
        Sh: currentData = byteOffset == 2 ? {newData[15:0],currentData[15:0]} : {currentData[31:16],newData[15:0]};
        Sb: begin
            case(byteOffset)
                0 : currentData = {currentData[31:8], newData[7:0]};
                1 : currentData = {currentData[31:16], newData[7:0], currentData[7:0]};
                2 : currentData = {currentData[31:24], newData[7:0], currentData[15:0]};
                3 : currentData = {newData[7:0], currentData[23:0]};
            endcase
        end
    endcase
    return currentData;
endfunction