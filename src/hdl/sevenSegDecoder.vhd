----------------------------------------------------------------------------------
-- Company: USAFA
-- Engineer: C3C Breen
-- 
-- Create Date: 02/19/2024 08:29:28 PM
-- Design Name: 
-- Module Name: sevenSegDecoder - Behavioral
-- Project Name: binaryHexDisp
-- Target Devices: Basay3 Board
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sevenSegDecoder is
    Port ( i_D : in STD_LOGIC_VECTOR (3 downto 0);
           o_S : out STD_LOGIC_VECTOR (6 downto 0));
end sevenSegDecoder;

architecture Behavioral of sevenSegDecoder is

begin
	
    o_S <= "1000000" when (i_D = "0000") else -- 0... G
	       "1111001" when (i_D = "0001") else -- 1... A, F, G, E, D
	       "0100100" when (i_D = "0010") else -- 2... F, C
	       "0110000" when (i_D = "0011") else -- 3... F, E
	       "0011001" when (i_D = "0100") else -- 4...A, E, D
           "0010010" when (i_D = "0101") else -- 5... B, E
           "0000010" when (i_D = "0110") else -- 6... B
           "1111000" when (i_D = "0111") else -- 7... F, G ,E , D
           "0000000" when (i_D = "1000") else -- 8... NONE
           "0011000" when (i_D = "1001") else -- 9... E, D
           "0001000" when (i_D = "1010") else -- 10 [A] ... D
           "0000011" when (i_D = "1011") else -- 11 [B] ...A, D
           "0100111" when (i_D = "1100") else -- 12 [C] ... A, B, C, F
           "0100001" when (i_D = "1101") else -- 13 [D] ... A, F
           "0000110" when (i_D = "1110") else -- 14 [E] ... B, C 
           "0001110" when (i_D = "1111") else -- 15 [F] ... B, C, D     
	"1111111";


end Behavioral;
