Full-bypassing 4 stage processor divided into fetch, decode, execute, and writeback stages. 
ALU.ms: ALU description. Uses a recursive adder to add left half then right half and then add the 2 togther to be more efficient (though taking up more area).
CacheHelpers.ms: Does basic functions to get the bits used for certain RISC-V instructions like Sw and Sh and Sb....
CacheTypes.ms: Describes some request structures and some dictionaries to describe some status bits
