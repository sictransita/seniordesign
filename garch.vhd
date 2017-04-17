library IEEE;
use ieee.numeric_std.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

library work;
use work.lfsr_pkg.ALL;

entity garch is
  generic ( NUM_BITS : integer := 16;
  BITS_H: integer := 15;
  BITS_L : integer := -15;
  PATHS : integer := 64);

  port  ( clk : in std_logic;
			rst : in std_logic;
			avg_prem : out ufixed (7 downto BITS_L + 7));
			
end garch;

architecture mc_sim of garch is

  -- RNG lfsr signals/constants
  constant set_seed : std_logic := '0';
  constant seed_lambda : std_logic_vector (BITS_H downto 0) := "0011101010010011";
  constant seed_eps : std_logic_vector (BITS_H downto 0) := "0110100110101101";
  signal lambda : ufixed (0 downto BITS_L) := "0000000000000000";
  signal epsilon : ufixed (0 downto BITS_L) := "0000000000000000";

  -- root calculation signals
  type array_root is array (0 to BITS_H) of unsigned (BITS_H downto 0);
  signal in_sqrt : array_root := (others => "0000000000000000");
  signal root : array_root := (others => "0000000000000000");
  signal sqrt_rem : array_root := (others => "0000000000000000");
  signal out_sqrt : unsigned (BITS_H downto 0) := "0000000000000000";
  signal out_sqrt_rem : unsigned (BITS_H downto 0) := "0000000000000000";
  constant MEDI : unsigned (BITS_H downto 0) := x"0001" sll BITS_H;
  constant MEDI2 : unsigned (BITS_H downto 0) := x"0001" sll BITS_H;

  -- garch output signals
  signal sigma : ufixed (0 downto BITS_L) := "0000000000000000";
  signal stock : ufixed (12 downto BITs_L) := "0000000000000000000000000000";

  -- wires in garch pipeline (refer to block diagram on google drive)
  --   #to# means pipeline stage # to #
  --> ex. w1to2 means wire from stage 1 to 2
  --   letter prefix (r, l, or c) denotes right, left, center respectively
  --> ex r3 means wire on the right in stage 3
  signal w1to2 : ufixed (1 downto BITS_L + BITS_L) := "00000000000000000000000000000000";
  signal w2to3 : ufixed (1 downto BITS_L + BITS_L) := "00000000000000000000000000000000";
  signal l3 : ufixed (1 downto BITS_L + BITS_L) := "00000000000000000000000000000000";
  signal r3 :ufixed (1 downto BITS_L + BITS_L) := "00000000000000000000000000000000";
  signal w3to4 : ufixed (2 downto BITS_L) := "000000000000000000";
  signal l4to5 : ufixed (1 downto BITS_L + BITS_L) := "00000000000000000000000000000000";
  signal c4to5 : ufixed (0 + NUM_BITS downto BITS_L) := "00000000000000000000000000000000";
  signal r4to5 : ufixed (1 downto BITS_L + BITS_L) := "00000000000000000000000000000000";
  signal w5to6 : ufixed (2 downto BITS_L + BITS_L) := "000000000000000000000000000000000";
  signal stock_pre : ufixed (13 downto BITS_L + BITS_L) := "00000000000000000000000000000000000000000000";
  signal premium_val : ufixed (13 downto BITS_L) := "00000000000000000000000000000";
  signal premium : ufixed (7 downto BITS_L + 7) := "0000000000000000";

  -- constants used in pipeline
  constant sigma0 : ufixed (0 downto BITS_L) := "0000010101101100"; -- 4 something percent
  constant stock0 : ufixed (12 downto BITS_L) := "1001000110001111001100110011"; -- 2328.95
  constant strike : ufixed (12 downto BITS_L) := "1001001011100000000000000000"; -- 2350.00
  constant barrier : ufixed (12 downto BITS_L) := "1001010001110000000000000000"; -- 2375.00
  constant alpha : ufixed (0 downto BITS_L) := "0001001111110100"; -- decimal 0.155900
  constant beta : ufixed (0 downto BITS_L) := "0110101110000101"; -- decimal 0.840000
  constant gamma : ufixed (0 downto BITS_L) := "0000000001000001"; -- dt/2
  constant eta : ufixed (0 downto BITS_L) := "1000000000000011"; -- 1 + mu*dt
  constant theta : ufixed (0 downto BITS_L) := "0000100000010000"; -- sqrt(dt)
  
  -- mux premium signals
  signal prem_sel : std_logic := '0';
  signal broke : std_logic := '0';
  
  -- premium array
  type prem_array is array (0 to PATHS) of ufixed (7 downto BITS_L + 7);
  signal path_prems : prem_array := (others => "0000000000000000");
  signal i_prem : integer := 0;
  signal avg : ufixed (7 downto BITS_L + 7) := "0000000000000000";

  -- days in stock year
  constant days : integer := 252;
  signal i_days : integer := 0;

  begin
    -- BEGIN PROCESSES
    -- ---------------
    -- loop through 252 days of stock market year
	 in_out:process(clk, rst)
	 begin
		if (rst = '1') then
			avg_prem <= "0000000000000000";
		elsif (clk'EVENT and clk = '1') then
			avg_prem <= avg;
		end if;
	 end process;
	 
    garch_io:process(clk, rst)
    begin
      -- clock edge and days counter
      if (rst = '1') then
			broke <= '0';
			i_days <= 0;

      elsif (clk'EVENT and clk = '1' and i_days < days) then
		  -- see if broke barrier
		  if (to_integer(stock) > to_integer(barrier)) then
				broke <= '1';
			end if;
        -- increment day count
		  i_days <= i_days + 1;
		  
		elsif (clk'EVENT and clk = '1' and i_days = days) then
			path_prems(i_prem) <= premium;
			i_prem <= i_prem + 1;
			i_days <= 0;
		end if;
    end process;

    -- lsfr RNG core
    lsfr:process(clk, i_days)
    -- variables for process
    variable rand_temp_eps : std_logic_vector (NUM_BITS-1 downto 0):=(0 => '1',others => '0');
    variable temp_eps : std_logic := '0';

    variable rand_temp_lambda : std_logic_vector (NUM_BITS-1 downto 0):=(0 => '1',others => '0');
    variable temp_lambda : std_logic := '0';

    begin
      -- clock edge
      if (rising_edge(clk) and i_days < days) then
        if (set_seed = '1') then
          rand_temp_lambda := seed_lambda;
          rand_temp_eps := seed_eps;
        end if;

        -- lambda assignments
        temp_lambda := xor_gates(rand_temp_lambda);
        rand_temp_lambda(NUM_BITS-1 downto 1) := rand_temp_lambda(NUM_BITS-2 downto 0);
        rand_temp_lambda(0) := temp_lambda;

        -- epsilon assignments
        temp_eps := xor_gates(rand_temp_eps);
        rand_temp_eps(NUM_BITS-1 downto 1) := rand_temp_eps(NUM_BITS-2 downto 0);
        rand_temp_eps(0) := temp_eps;
      end if;

      lambda <= ufixed(rand_temp_lambda);
      epsilon <= ufixed(rand_temp_eps);

    end process;

    -- square root core
    square_root:process(in_sqrt, root, sqrt_rem, w3to4, i_days)
    begin
		if (i_days < days) then
        -- declare initial array values
        in_sqrt(0) <= unsigned(w3to4(0 downto BITS_L));
        root(0) <= MEDI;
        sqrt_rem(0) <= MEDI2;

        -- root i/o operations
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

    -- pipeline core
    pipeline:process(clk)
    begin
      -- clock edge
      if (rising_edge(clk) and i_days < days) then
        -- pipeline loop
        for i in 1 to 7 loop
          case i is
            -- stage 1
            when 1 => w1to2 <= lambda * lambda;

            -- stage 2
            when 2 => w2to3 <= w1to2(0 downto BITS_L) * beta;

            -- stage 3
            when 3 => l3 <= w3to4(0 downto BITS_L) * w2to3(0 downto BITS_L);
            r3 <= w3to4(0 downto BITS_L) * alpha;
            w3to4 <= l3(0 downto BITS_L) + r3(0 downto BITS_L) + sigma0;

            -- stage 4
            when 4 => c4to5 <= ufixed(out_sqrt);
            r4to5 <= epsilon * theta;
            l4to5 <= w3to4(0 downto BITS_L) * gamma; -- does this resizing capture correct bits?
            sigma <= ufixed(out_sqrt); -- if not resized correctly then set to all 1's

            -- stage 5
            when 5 => w5to6 <= (eta - l4to5(0 downto BITS_L)) + r4to5(0 downto BITS_L) * c4to5(0 downto BITS_L);
							 
				when 6 => stock_pre <= stock0 * w5to6(0 downto BITS_L);
							 stock <= stock_pre(12 downto BITS_L);

            when others => null;
          end case;
        end loop;
      end if;
    end process;
	 
	 premium_calc:process(i_days, stock, premium_val, broke)
	 variable premium_diff : integer := 0;
	 begin
		premium_val <= stock - strike;
		if (i_days < days + 1) then			
			if ((to_integer(unsigned(stock)) > to_integer(unsigned(strike))) and broke = '1') then
				premium <= premium_val(7 downto BITS_L + 7);
			else
				premium <= "0000000000000000";
			end if;	
		end if;
	end process;

    -- -------------
    -- END PROCESSES
  end mc_sim;
