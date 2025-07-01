
// Description: 32-bit right barrel shifter
// Arguments: in (value to be shifted); sftSz (shift size); sft_in (the bit shifted in)
// Return: {sft_in's, in[31:sftSz]}
function Bit#(32) barrelRShift(Bit#(32) in, Bit#(5) sftSz, Bit#(1) sft_in);
    Bit#(32) ret = in;
    //////////////////
    // If a given bit is 1, will sign extend that number of bits with sft_in as most signifcant bit
    ret = sftSz[4] == 1 ? signExtend({sft_in, ret[31:16]}) : ret;
    ret= sftSz[3] == 1 ? signExtend({sft_in, ret[31:8]}) : ret;
    ret =sftSz[2] == 1 ? signExtend({sft_in, ret[31:4]}) : ret;
    ret= sftSz[1] == 1 ? signExtend({sft_in, ret[31:2]}) : ret;
    ret = sftSz[0] == 1 ? signExtend({sft_in, ret[31:1]}) : ret;
    /////////////////
    return ret;
endfunction
// Description: 32-bit arithmetic/logic right shifter
// Arguments: in (value to be shifted); sftSz (shift size); arith (1 = arithmetic, 0 = logic)
// Return: in >> sftSz
function Bit#(32) sr32(Bit#(32) in, Bit#(5) sftSz, Bit#(1) arith);
    Bit#(32) ret = 0;
    //////////////////
    // YOUR CODE HERE
    /////////////////
    Bit#(1) sft_in = arith == 1 ? in[31] : 0;
    // ret = arith == 1 ?  barrelRShift(in, sftSz, in[31]) : barrelRShift(in, sftSz, 0);
    return barrelRShift(in, sftSz, sft_in);
endfunction
// Description: 32-bit logic left shifter
// Arguments: in (values to be shifted); sftSz (shift size)
// Return: a << b
function Bit#(32) sll32(Bit#(32) in, Bit#(5) sftSz);
    Bit#(32) ret = 0;
    //////////////////
    // YOUR CODE HERE
    ret = reverseBits(in);
    ret = sr32(ret, sftSz, 0);
    ret = reverseBits(ret);
    /////////////////
    return ret;
endfunction
// Description: 32-bit FULL shifter
// Arguments: in (value to be shifted); sftSz (shift size);
// ShiftTypes:
// LogicalRightShift
// ArithmeticRightShift
// LeftShift
//
// Return: in >> sftSz when right shift; in << sftSz otherwise
typedef enum {LogicalRightShift, ArithmeticRightShift, LeftShift} ShiftType;
function Bit#(32) sft32(Bit#(32) in, Bit#(5) sftSz, ShiftType shiftType);
    Bit#(32) ret = in;
    //////////////////
    // first assigns do_reverse and msb (args for barrelRShift) and then
    // runs barrelRShift whith certain args depending on do_reverse and msb values
    Bool do_reverse = shiftType == LeftShift ? True : False;
    Bit#(1) msb = shiftType == ArithmeticRightShift ? in[31] : 0;
    ret = do_reverse ? reverseBits(ret) : ret;
    ret = barrelRShift(ret, sftSz, msb);
    ret = do_reverse ? reverseBits(ret) : ret;
    /////////////////
    return ret;
endfunction
// Description: one-bit less-than comparator
// Arguments: a, b (1-bit values), eq, lt (eq and lt from previous comparator)
// Return: {eq_i, lt_i}
function Bit#(2) cmp(Bit#(1) a, Bit#(1) b, Bit#(1) eq, Bit#(1) lt);
    //////////////////
    // equal if a equals b and was equal before
    // lt if previously less than or if was previously equal and a is less than b
    Bit#(1) eq_i = ((a & b) | (~a & ~b)) & eq;
    Bit#(1) lt_i = lt | (eq & ~a & b);
    /////////////////
    return {eq_i, lt_i};
endfunction
// Description: unsigned 32-bit less-than comparator
// Arguments: a, b unsigned 32-bit values
// Return: 1 if a < b
function Bit#(1) ltu32(Bit#(32) a, Bit#(32) b);
    Bit#(2) result = 0;
    Bit#(1) eq = 1;
    Bit#(1) lt = 0;
    //////////////////
    for (Integer i = 31; i >= 0; i = i - 1) begin
        result = cmp(a[i], b[i], eq, lt);
        eq = result[1];
        lt = result[0];
    end
    /////////////////
    return lt;
endfunction
// Description: Signed/Unsigned 32-bit less-than comparator
// Arguments: a b (32-bit values); isSigned (signed comparator when 1, unsigned otherwise)
// Return: 1 if a < b
function Bit#(1) lt32(Bit#(32) a, Bit#(32) b, Bit#(1) isSigned);
    Bit#(1) ret = 0;
    //////////////////
    // call ltu32 on the 31 leasy significant bits, then based on
    // values of msb and isSigned return the result
    Bit#(1) eq = (a[31] & b[31]) | (~a[31] & ~b[31]);
    Bit#(1) lt = isSigned == 1 ? (a[31] & ~b[31]) : (~a[31] & b[31]);
    Bit#(1) result = ltu32({0, a[30:0]}, {0, b[30:0]});
    ret = lt | (result & eq);
    /////////////////
    return ret;
endfunction
// Description: one-bit full adder
// Arguments: a, b, carry in
// Return: {carry out, sum}
function Bit#(2) fullAdder(Bit#(1) a, Bit#(1) b, Bit#(1) carryIn);
    //////////////////
    // YOUR CODE HERE
    Bit#(1) carry_out = (a & b) | (carryIn & (a | b));
    Bit#(1) sum = (((~a & b) | (a & ~b)) & ~carryIn) | (carryIn & ~((~a & b) | (a & ~b)));
    /////////////////
    return {carry_out, sum};
endfunction
// Description: n-bit ripple-carry adder with a carry-in
// Arguments: a, b, carryIn
// Return: sum of a, b, and carryIn
function Bit#(n) rca#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) carryIn);
    Bit#(n) ret = 0;
    Bit#(1) carry = carryIn;
    //////////////////
    // YOUR CODE HERE
    // calls the full adder on the first bit, then on every consequent set of bits for the entire length of n
    for (Integer i = 0; i < n; i = i + 1) begin
        Bit#(2) result = fullAdder(a[i], b[i], carry);
        ret[i] = result[0];
        carry = result[1];
    end
    /////////////////
    return ret;
endfunction
// Description: n-bit ripple-carry adder/subractor
// Arguments: a, b (n-bit operands); isSub (1 => subtract, 0 => add)
// Return: isSub == 0 ? a + b : a - b
function Bit#(n) addSub#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) isSub);
    Bit#(n) ret = 0;
    //////////////////
    // YOUR CODE HERE
    // adds the 2 numbers using rca function, and if subtracting then inverts b and adds 1 to carryin
    Bit#(n) b_val = isSub == 1 ? ~b : b;
    Bit#(1) carryIn = isSub == 1 ? 1 : 0;
    /////////////////
    return fastAdd# (n)(a, b_val, carryIn);
endfunction
// Alu Functions:
// Add: 32-bit Addition         (a + b)
// Sub: 32-bit Subtraction      (a - b)
// And: 32-bit Bitwise And      (a & b)
// Or: 32-bit Bitwise Or        (a | b)
// Xor: 32-bit Bitwise Xor      (a ^ b)
// Slt: Set less than           (a <u b ? 1 : 0)
// Sltu: Set less than unsigned (a <s b ? 1:0)
// Sll: Left logic shfit        (a << b)
// Srl: Right logic shift       (a >>u b)
// Sra: Right arithmetic shift  (a >>s b)
typedef enum {Add, Sub, And, Or, Xor, Slt, Sltu, Sll, Srl, Sra} AluFunc;
// Description: Arithmetic Logic Unit (ALU)
// Arguments: a, operand a; b, operand b; func, ALU operation
// Return: output of ALU
function Bit#(32) alu(Bit#(32) a, Bit#(32) b, AluFunc func);
    Bit #(32) ret = 0;
    //////////////////
    // YOUR CODE HERE
    if (func == Add || func == Sub) begin
        Bit#(1) isSub = func == Sub ? 1 : 0;
        ret = addSub#(32)(a, b, isSub);
    end
    else if (func == Slt || func == Sltu) begin
        Bit#(1) isSigned = func == Sltu ? 0 : 1;
        ret = zeroExtend(lt32(a, b, isSigned));
    end
    else if (func == Sll || func == Srl || func == Sra) begin
        ShiftType shiftType = LogicalRightShift;
        if (func == Sll) shiftType = LeftShift;
        else if (func == Sra) shiftType = ArithmeticRightShift;
        ret = sft32(a, b[4:0], shiftType);
    end
    else if (func == And) ret = a & b;
    else if (func == Or) ret = a | b;
    else if (func == Xor) ret = a ^ b;
    /////////////////
    return ret;
endfunction
function Tuple2#(Bit#(n), Bit#(1)) recursiveAdd#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) carryIn);
    //recursive function to get add the bits using tuples of the sum and the carryout
    if (n == 1) begin
        let result = fullAdder(a, b, carryIn);
        return tuple2(result[0], result[1]); // tuple with sum, carryout
    end
    else begin
        //divide each list into 2
        let n_left = (n + 1) / 2; // Calculate left width (rounds up)
        let n_right = n / 2;     // Calculate right width (rounds down)

        let a_left = a[n-1: n-n_left];
        let a_right = a[n_right - 1: 0];
        let b_left = b[n-1: n-n_left];
        let b_right = b[n_right- 1: 0];

        //make the recursive calls for each possible carryin possibility
        let left_result0 = recursiveAdd#(n_left)(a_left, b_left, 0);
        let left_result1 = recursiveAdd#(n_left)(a_left, b_left, 1);
        let right_result0 = recursiveAdd#(n_right)(a_right, b_right, 0);
        let right_result1 = recursiveAdd#(n_right)(a_right, b_right, 1);

        let right_result = carryIn == 0 ? right_result0 : right_result1;
        let left_result = right_result.snd == 0 ? left_result0 : left_result1;
        //let left_result = carryIn == 0 ? left_result0 : left_result1;
        //let right_result = left_result.snd == 0 ? right_result0 : right_result1;

        return tuple2({left_result.fst, right_result.fst}, left_result.snd);
    end
endfunction
function Bit#(n) fastAdd#(Integer n)(Bit#(n) a, Bit#(n) b, Bit#(1) carryIn);
    let ret = recursiveAdd#(n)(a, b,carryIn);
    //////////////////
    // returns the sum part of the tuple from recursiveAdd
    return ret.fst;
    /////////////////
endfunction