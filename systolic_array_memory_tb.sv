// systolic array memory testbench

`include "systolic_array_tc.svh"

module systolic_array_memory_tb();

   localparam BITS_AB=8;
   localparam BITS_C=16;
   localparam DIM=8;
   localparam ROWBITS=$clog2(DIM);
   
   localparam TESTS=10;
   
   // Clock
   logic clk;
   logic rst_n;
   logic en, en_memA, en_memB;
   logic WrEn_SA, WrEn_A;
   logic [ROWBITS-1:0] Crow;
   logic [ROWBITS-1:0] Arow;
   logic signed [BITS_AB-1:0] A [DIM-1:0];
   logic signed [BITS_AB-1:0] B [DIM-1:0];
   logic signed [BITS_C-1:0] Cin [DIM-1:0];
   logic signed [BITS_C-1:0] Cout [DIM-1:0];
   logic signed [BITS_C-1:0] Coutreg [DIM-1:0];

   logic signed [BITS_AB-1:0] Amem_int [DIM-1:0];
   logic signed [BITS_AB-1:0] Bmem_int [DIM-1:0];
   
   logic signed [BITS_AB-1:0] nextA [DIM-1:0];
   logic signed [BITS_AB-1:0] nextB [DIM-1:0];

   always #5 clk = ~clk; 

   integer errors,mycycle;

   systolic_array #(.BITS_AB(BITS_AB),
                    .BITS_C(BITS_C),
                    .DIM(DIM))
                    systolic_array_DUT (.clk(clk),
                                        .rst_n(rst_n),
                                        .en(en),
                                        .WrEn(WrEn_SA),
                                        .A(Amem_int),
                                        .B(Bmem_int),
                                        .Cin(Cin),
                                        .Crow(Crow),
                                        .Cout(Cout)
                                        );

   memA #(.BITS_AB(BITS_AB),
          .DIM(DIM))
          memA_DUT (.clk(clk),
                    .rst_n(rst_n),
                    .en(en_memA),
                    .WrEn(WrEn_A),
                    .Ain(A),
                    .Arow(Arow),
                    .Aout(Amem_int)
                    );

   memB #(.BITS_AB(BITS_AB),
          .DIM(DIM))
          memB_DUT (.clk(clk),
                    .rst_n(rst_n),
                    .en(en_memB),
                    .Bin(B),
                    .Bout(Bmem_int)
                    );

   systolic_array_tc #(.BITS_AB(BITS_AB),
                       .BITS_C(BITS_C),
                       .DIM(DIM)
                       ) satc;

  // register Cout values
  always @(posedge clk) begin
    Coutreg <= Cout;
  end
   
  initial begin
	for (int testCase = 0; testCase < 100; testCase++) begin
	  clk = 1'b0;
	  rst_n = 1'b1;
	  en = 1'b0;
	  en_memA = 1'b0;
	  en_memB = 1'b0;
	  WrEn_SA = 1'b0;
	  WrEn_A = 1'b0;
    Arow = 1'b0;
	  errors = 0;
    Crow = {ROWBITS{1'b0}};
	  for(int rowcol=0;rowcol<DIM;++rowcol) begin
		  A[rowcol] = {BITS_AB{1'b0}};
		  B[rowcol] = {BITS_AB{1'b0}};
		  Cin[rowcol] = {BITS_C{1'b0}};
	  end
      
	  // reset and check Cout
	  @(posedge clk) begin end
	  rst_n = 1'b0; // active low reset
    @(posedge clk) begin end
    rst_n = 1'b1; // reset finished
	  @(posedge clk) begin end

    // check that C was properly reset
    for(int Row=0;Row<DIM;++Row) begin
      Crow = {Row[ROWBITS-1:0]};
      @(posedge clk) begin end
      for(int Col=0;Col<DIM;++Col) begin
        if(Coutreg[Col] !== 0) begin
		      errors++;
		      $display("Error! Reset was not conducted properly. Expected: 0, Got: %d for Row %d Col %d", Coutreg[Col],Row, Col); 
	      end
      end
    end
	
      // instantate test case
      satc = new();

      @(posedge clk);
      for(int i = 0; i < DIM; i++) begin
        Cin[i] = {BITS_C{1'b0}};
      end
    
      @(posedge clk);
    
      WrEn_SA = 1'b1;
      for(int Row=0;Row<DIM;++Row) begin
        Crow = {Row[ROWBITS-1:0]};
        @(posedge clk) begin end
      end
    
      WrEn_SA = 1'b0;

      // LOAD memA
      WrEn_A = 1'b1;
      for (int i = 0; i < DIM; i++) begin // cycles
        Arow = {i[ROWBITS-1:0]};
        A = {satc.A[i]};
      @(posedge clk);
      end
      WrEn_A = 1'b0;

      // LOAD memB
      en_memB = 1'b1;
      for (int i = 0; i < DIM; i++) begin
        B = {satc.B[i]};
        @(posedge clk);
      end
	  
	  // set the input values to be 0
	  for(int rowcol=0;rowcol<DIM;++rowcol) begin
		  A[rowcol] = {BITS_AB{1'b0}};
		  B[rowcol] = {BITS_AB{1'b0}};
	  end
	  
      en_memA = 1'b1;
      en = 1'b1;
      // Compare values of memA and memB to expected values
      for (int i = 0; i < ((DIM * 3) - 2); i++) begin
        
        // clock cycle
        @(posedge clk);
      
        // for loop to initialized the next values for a certain row
        for(int col = 0; col < DIM; col++) begin
          nextA[col] = satc.get_next_A(col);
          nextB[col] = satc.get_next_B(col);
        end

        // check A and B
        if (Amem_int != nextA) begin
          $display("Error in A: exptected %p, got %p", nextA, Amem_int);
          errors++;
        end
      
        if (Bmem_int != nextB) begin
          $display("Error in B: exptected %p, got %p", nextB, Bmem_int);
          errors++;
        end
      
        // next cycle
        mycycle = satc.next_cycle();
      end

      // compute is done
      en_memA = 1'b0;
      en_memB = 1'b0;
      en = 1'b0;

      @(posedge clk) begin end
      // read Cout row by row and check against test case
      for(int Row=0;Row<DIM;++Row) begin
        Crow = {Row[ROWBITS-1:0]};
        @(posedge clk) begin end
        errors = errors + satc.check_row_C(Row,Cout);
        @(posedge clk) begin end
      end
         
      if (errors > 0) begin
        $display("Errors found: %d, dumping test case\n",errors);
        satc.dump();
        $display("Dumping result");
        @(posedge clk) begin end
        for(int Row=0;Row<DIM;++Row) begin
          Crow = {Row[ROWBITS-1:0]};
          @(posedge clk) begin end
          for(int Col=0;Col<DIM;++Col) begin
            $write("%5d ",Cout[Col]);
          end
          $display("");
          @(posedge clk) begin end
        end
      end
      else begin
        $display("No errors, testcase passed\n");
      end

      satc = null;

    end

    $stop;

   end // initial begin

endmodule // systolic_array_memory_tb
