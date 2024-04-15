--+----------------------------------------------------------------------------
--| 
--| COPYRIGHT 2018 United States Air Force Academy All rights reserved.
--| 
--| United States Air Force Academy     __  _______ ___    _________ 
--| Dept of Electrical &               / / / / ___//   |  / ____/   |
--| Computer Engineering              / / / /\__ \/ /| | / /_  / /| |
--| 2354 Fairchild Drive Ste 2F6     / /_/ /___/ / ___ |/ __/ / ___ |
--| USAF Academy, CO 80840           \____//____/_/  |_/_/   /_/  |_|
--| 
--| ---------------------------------------------------------------------------
--|
--| FILENAME      : top_basys3.vhd
--| AUTHOR(S)     : Capt Phillip Warner
--| CREATED       : 3/9/2018  MOdified by Capt Dan Johnson (3/30/2020)
--| DESCRIPTION   : This file implements the top level module for a BASYS 3 to 
--|					drive the Lab 4 Design Project (Advanced Elevator Controller).
--|
--|					Inputs: clk       --> 100 MHz clock from FPGA
--|							btnL      --> Rst Clk
--|							btnR      --> Rst FSM
--|							btnU      --> Rst Master
--|							btnC      --> GO (request floor)
--|							sw(15:12) --> Passenger location (floor select bits)
--| 						sw(3:0)   --> Desired location (floor select bits)
--| 						 - Minumum FUNCTIONALITY ONLY: sw(1) --> up_down, sw(0) --> stop
--|							 
--|					Outputs: led --> indicates elevator movement with sweeping pattern (additional functionality)
--|							   - led(10) --> led(15) = MOVING UP
--|							   - led(5)  --> led(0)  = MOVING DOWN
--|							   - ALL OFF		     = NOT MOVING
--|							 an(3:0)    --> seven-segment display anode active-low enable (AN3 ... AN0)
--|							 seg(6:0)	--> seven-segment display cathodes (CG ... CA.  DP unused)
--|
--| DOCUMENTATION : None
--|
--+----------------------------------------------------------------------------
--|
--| REQUIRED FILES :
--|
--|    Libraries : ieee
--|    Packages  : std_logic_1164, numeric_std
--|    Files     : MooreElevatorController.vhd, clock_divider.vhd, sevenSegDecoder.vhd
--|				   thunderbird_fsm.vhd, sevenSegDecoder, TDM4.vhd, OTHERS???
--|
--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset
        btnD    :   in std_logic;
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
	-- declare components and signals
	
-- SEVENSEG DECODER...
component sevenSegDecoder is
        Port ( i_D : in STD_LOGIC_VECTOR (3 downto 0);
               o_S : out STD_LOGIC_VECTOR (6 downto 0));
    end component sevenSegDecoder;	
	
--BASIC FSM
component elevator_controller_fsm is
        Port ( i_clk     : in  STD_LOGIC;
               i_reset   : in  STD_LOGIC;
               i_stop    : in  STD_LOGIC;
               i_up_down : in  STD_LOGIC;
               o_floor   : out STD_LOGIC_VECTOR (3 downto 0)           
             );
    end component elevator_controller_fsm;

-- TDM (ADVANCED FUNCTIONALITY)
component TDM4 is
	generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
    Port ( i_clk_tdm		: in  STD_LOGIC;
           i_reset_tdm		: in  STD_LOGIC; -- asynchronous
           i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	);
end component TDM4;
	
-- CLOCK
component clock_divider is
	generic ( constant k_DIV : natural := 25000000	); -- How many clk cycles until slow clock toggles
											   -- Effectively, you divide the clk double this 
											   -- number (e.g., k_DIV := 2 --> clock divider of 4)
	port ( 	i_clk    : in std_logic;
			i_reset  : in std_logic;		   -- asynchronous
			o_clk    : out std_logic		   -- divided (slow) clock
	);
end component clock_divider;
	
	
	signal w_clk : STD_LOGIC := '0';
	signal w_Floor : STD_LOGIC_VECTOR (3 downto 0) := "0010";
	signal w_reset_clk_div : STD_LOGIC := '0';
	signal w_reset_elv_cont : STD_LOGIC := '0';
	signal w_reset_tdm : STD_LOGIC := '0';
	
	signal w_tdm_clk_input : STD_LOGIC := '0';
	
	signal w_D2 : STD_LOGIC_VECTOR (3 downto 0) := "0000";
	signal w_D3 : STD_LOGIC_VECTOR (3 downto 0) := "0000";
	
	signal w_data : STD_LOGIC_VECTOR (3 downto 0) := "0000";
	signal w_sel : STD_LOGIC_VECTOR (3 downto 0) := "0000";
	
	
	
begin
	-- PORT MAPS ----------------------------------------

clock_divider_inst_fsm : clock_divider
    port map(
             i_clk => clk, 
             i_reset => w_reset_clk_div,
             o_clk => w_clk
             );
             
clock_divider_inst_tdm : clock_divider
    generic map(k_DIV => 25000)
     port map(
              i_clk => clk, 
              i_reset => w_reset_clk_div,
              o_clk => w_tdm_clk_input 
              );

tdm4_inst : TDM4
    port map( 
          i_clk_tdm => w_tdm_clk_input,
          i_reset_tdm => w_reset_tdm,
          i_D3 => w_D3,
          i_D2 => w_D2,
          i_D1 => "0000",
          i_D0 => "0000",
          o_data => w_data,
          o_sel => w_sel
          );

elevator_contoller_fsm_inst : elevator_controller_fsm 
    port map(
             i_reset => w_reset_elv_cont,
             i_stop => sw(0), 
             i_up_down => sw(1), 
             i_clk => w_clk,
             o_floor => w_Floor
             );
	
	
sevenSegDecoder_inst : sevenSegDecoder 
    port map(
             i_D => w_data,
             o_S => seg
                );
	
	
	-- CONCURRENT STATEMENTS ----------------------------
	
	w_reset_clk_div <= ((btnL) or (btnU));
	w_reset_elv_cont <= ((btnR) or (btnU));
	w_reset_tdm <= ((btnU) or (btnD));
	
	
	w_D3 <= "0001" when(w_Floor = "1010") else -- 10
	        "0001" when(w_Floor = "1011") else -- 11
	        "0001" when(w_Floor = "1100") else -- 12
            "0001" when(w_Floor = "1101") else -- 13
            "0001" when(w_Floor = "1110") else -- 14
            "0001" when(w_Floor = "1111") else -- 15
            "0001" when(w_Floor = "0000") else -- 16
            "0000";
	
	w_D2 <= "0001" when(w_Floor = "0001") else -- 01
	        "0010" when(w_Floor = "0010") else -- 02
            "0011" when(w_Floor = "0011") else -- 03
            "0100" when(w_Floor = "0100") else -- 04
            "0101" when(w_Floor = "0101") else -- 05
            "0110" when(w_Floor = "0110") else -- 06
            "0111" when(w_Floor = "0111") else -- 07
            "1000" when(w_Floor = "1000") else -- 08
            "1001" when(w_Floor = "1001") else -- 09
            "0000" when(w_Floor = "1010") else -- 10, Digit 2 needs to be 0...
            "0001" when(w_Floor = "1011") else -- 11, Digit 2 needs to be 1...
            "0010" when(w_Floor = "1100") else -- 12, Digit 2 needs to be 2...
            "0011" when(w_Floor = "1101") else -- 13
            "0100" when(w_Floor = "1110") else -- 14
            "0101" when(w_Floor = "1111") else -- 15
            "0110" when(w_Floor = "0000") else -- 16
            "0000"; 
            
  an(0) <= '1';
  an(1) <= '1';
  an(2) <= '0' when (w_sel = "1011" ) else '1';
  an(3) <= '0' when (w_sel = "0111" ) else '1';
	
	
	-- LED 15 gets the FSM slow clock signal. The rest are grounded.
	
    led(15) <= w_clk; 
    led(14 downto 0) <= "000000000000000";
	-- leave unused switches UNCONNECTED. Ignore any warnings this causes.

       	
end top_basys3_arch;
