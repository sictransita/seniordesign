library IEEE;
use ieee.numeric_std.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity root_loop is
  generic ( NUM_BITS : integer := 16;
            BITS_H: integer := 15;
            BITS_L : integer := -15);

  port  ( clk : in std_logic;
          x : in unsigned (BITS_H downto 0);
			 out_sqrt : out unsigned (BITS_H downto 0);
			 out_sqrt_rem : out unsigned (BITS_H downto 0));

end root_loop;

architecture root_cycle of root_loop is

  
  type array_root is array (0 to BITS_H) of unsigned (BITS_H downto 0);
  signal in_sqrt : array_root;
  signal root : array_root;
  signal sqrt_rem : array_root;
  --signal out_sqrt : ufixed (0 downto BITS_L) := "0000000000000000";
  --signal out_sqrt_rem : ufixed (0 downto BITS_L) := "0000000000000000";
  constant MEDI : unsigned (63 downto 0) := x"0000000000000001" sll BITS_H;
  constant MEDI2 : unsigned (63 downto 0) := x"0000000000000001" sll BITS_H;

  begin


  -- process for root
  process(clk)
  begin
    -- clock edge
    if (clk'EVENT and clk = '1') then
	 
	   -- declare initial array values
  in_sqrt(0) <= x;
  root(0) <= MEDI;
  sqrt_rem(0) <= MEDI2;

		-- root i/o conversions
    for ind in 0 to BITS_H - 1 loop
      if (to_integer(in_sqrt(ind)) > to_integer(sqrt_rem(ind))) then
        root(ind + 1) <= resize(root(ind) + (MEDI srl (ind + 1)), 16);
        sqrt_rem(ind + 1) <= resize(sqrt_rem(ind) + (MEDI2 srl (2*(ind+1))) + (root(ind) srl ind), 16);
      else
        root(ind + 1) <= resize (root(ind) - (MEDI srl (ind + 1)), 16);
        sqrt_rem(ind + 1) <= resize (sqrt_rem(ind) + (MEDI2 srl (2*(ind+1))) - (root(ind) srl ind), 16);
      end if;
      in_sqrt(ind + 1) <= in_sqrt(ind);
    end loop;

    out_sqrt <= root(BITS_H);
    out_sqrt_rem <= sqrt_rem(BITS_H);

      
    end if;
  end process;

end root_cycle;


