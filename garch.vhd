library IEEE;
use ieee.numeric_std.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;
use ieee.std_logic_arith.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

library work;
use work.lfsr_pkg.ALL;

entity garch is
  generic ( NUM_BITS : integer := 16;
  BITS_H: integer := 15;
  BITS_L : integer := -15);

  port  ( clk : in std_logic;
  rst : in std_logic;
  set_seed : in std_logic;
  seed_lambda : in unsigned (0 downto BITS_L);
  seed_eps : in unsigned (0 downto BITS_L);
  sigma0 : in ufixed (0 downto BITS_L); -- taken out

  q : out ufixed (0 downto BITS_L);
  weps : out ufixed (0 downto BITS_L);
  sigma : out ufixed (0 downto BITS_L)); -- necessary?
end garch;

architecture mc_sim of garch is

  -- iternal signals from flop inputs/ to flop outputs
  signal in_set_seed : std_logic := 0;
  signal in_seed_lambda : unsigned (BITS_H downto 0) := "0000000000000000";
  signal in_seed_eps : unsigned (BITS_H downto 0) := "0000000000000000";
  signal in_sigma0 : ufixed (0 downto BITS_L) := "0000000000000000";

  -- RNG lfsr output signals
  signal lambda : ufixed (0 downto BITS_L) := "0000000000000000";
  signal epsilon : ufixed (0 downto BITS_L) := "0000000000000000";

  -- root calculation signals
  type array_root is array (0 to BITS_H) of unsigned (BITS_H downto 0);
  signal in_sqrt : array_root;
  signal root : array_root;
  signal sqrt_rem : array_root;
  signal out_sqrt : unsigned (BITS_H downto 0) := "0000000000000000";
  signal out_sqrt_rem : unsigned (BITS_H downto 0) := "0000000000000000";
  --signal out_sqrt : ufixed (0 downto BITS_L) := "0000000000000000";
  --signal out_sqrt_rem : ufixed (0 downto BITS_L) := "0000000000000000";
  constant MEDI : unsigned (63 downto 0) := x"0000000000000001" sll BITS_H;
  constant MEDI2 : unsigned (63 downto 0) := x"0000000000000001" sll BITS_H;

  -- output signals
  signal out_q : ufixed (0 downto BITS_L) := "0000000000000000";
  signal out_weps : ufixed (0 downto BITS_L) := "0000000000000000";
  signal out_sigma : ufixed (0 downto BITS_L) := "0000000000000000";


  -- wires in garch pipeline (refer to block diagram on google drive)
  --   #to# means pipeline stage # to #
  --> ex. w1to2 means wire from stage 1 to 2
  --   letter prefix (r, l, or c) denotes right, left, center respectively
  --> ex r3 means wire on the right in stage 3
  signal w1to2 : ufixed (0 downto BITS_L) := "0000000000000000";
  signal w2to3 : ufixed (0 downto BITS_L) := "0000000000000000";
  signal l3 : ufixed (0 downto BITS_L) := "0000000000000000";
  signal r3 :ufixed (0 downto BITS_L) := "0000000000000000";
  signal w3to4 : ufixed (0 downto BITS_L) := "0000000000000000";
  signal l4to5 : ufixed (0 downto BITS_L) := "0000000000000000";
  signal c4to5 : ufixed (0 downto BITS_L) := "0000000000000000";
  signal r4to5 : ufixed (0 downto BITS_L) := "0000000000000000";

  -- constants used in pipeline
  constant alpha : ufixed (0 downto BITS_L) := "0001001111110100"; -- decimal 0.155900
  constant beta : ufixed (0 downto BITS_L) := "0110101110000101"; -- decimal 0.840000
  constant gamma : ufixed (0 downto BITS_L) := "0000000000000000"; -- dt/2
  constant eta : ufixed (0 downto BITS_L) := "0000000000000000"; -- 1 + mu*dt
  constant theta : ufixed (0 downto BITS_L) := "0000000000000000"; -- sqrt(dt)

  -- days in stock year
  constant days : integer := 252;

  begin
    -- BEGIN PROCESSES
    -- ---------------
    -- loop through 252 days of stock market year
    in_out:process(clk)

    variable i_days : integer := 0;
    begin
      -- clock edge and days counter
      if (rst = '1') then
        in_set_seed <= 0;
        in_seed_lambda <= "0000000000000000";
        in_seed_eps <= "0000000000000000";
        in_sigma0 <= "0000000000000000";

        q <= "0000000000000000";
        weps <= "0000000000000000";
        sigma <= "0000000000000000";

      elsif (clk'EVENT and clk = '1' and i_days < days) then
        -- input flops
        in_set_seed <= set_seed;
        in_seed_lambda <= seed_lambda;
        in_seed_eps <= seed_eps;
        in_sigma0 <= sigma0;

        -- output flops
        q <= out_q;
        weps <= out_weps;
        sigma <= out_sigma;

        -- increment day count
        i_days := i_days + 1;
      end if;
    end process;

    -- lsfr RNG core
    lsfr:process(clk)
    -- variables for process
    variable rand_temp_eps : std_logic_vector (width-1 downto 0):=(0 => '1',others => '0');
    variable temp_eps : std_logic := '0';

    variable rand_temp_lambda : std_logic_vector (width-1 downto 0):=(0 => '1',others => '0');
    variable temp_lambda : std_logic := '0';

    begin
      -- clock edge
      if (clk'EVENT and clk = '1') then
        if (in_set_seed = '1') then
          rand_temp_lambda := in_seed_lambda;
          rand_temp_eps := in_seed_eps;
        end if;

        -- lambda assignments
        temp_lambda := xor_gates(rand_temp_lambda);
        rand_temp_lambda(width-1 downto 1) := rand_temp_lambda(width-2 downto 0);
        rand_temp_lambda(0) := temp_lambda;

        -- epsilon assignments
        temp_eps := xor_gates(rand_temp_eps);
        rand_temp_eps(width-1 downto 1) := rand_temp_eps(width-2 downto 0);
        rand_temp_eps(0) := temp_eps;
      end if;

      lambda <= ufixed(rand_temp_lambda);
      epsilon <= ufixed(rand_temp_eps);

    end process;

    -- square root core
    square_root:process(clk)
    begin
      -- clock edge
      if (clk'EVENT and clk = '1') then
        -- declare initial array values
        in_sqrt(0) <= unsigned(w3to4);
        root(0) <= MEDI;
        sqrt_rem(0) <= MEDI2;

        -- root i/o operations
        for ind in 0 to BITS_H - 1 loop
          if (conv_integer(in_sqrt(ind)) > conv_integer(sqrt_rem(ind))) then
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
      if (clk'EVENT and clk = '1') then
        -- pipeline loop
        for i in 1 to 7 loop
          case i is
            -- stage 1
            when 1 => w1to2 <= resize(in_lambda * in_lambda, w1to2);

            -- stage 2
            when 2 => w2to3 <= resize(w1to2 * beta, w2to3);

            -- stage 3
            when 3 => l3 <= resize(w3to4 * w2to3, l3);
            r3 <= resize(w3to4 * alpha, r3);
            w3to4 <= resize(l3 + r3 + in_sigma0, w3to4);

            -- stage 4
            when 4 => c4to5 <= ufixed(out_sqrt);
            r4to5 <= resize(in_epsilon * theta, r4to5);
            l4to5 <= resize(w3to4 * gamma, l4to5); -- does this resizing capture correct bits?
            out_sigma <= ufixed(out_sqrt); -- if not resized correctly then set to all 1's

            -- stage 5
            when 5 => out_weps <= resize(r4to5 * c4to5, out_weps);
            out_q <= resize(eta - l4to5, out_q);

            when others => null;
          end case;
        end loop;
      end if;
    end process;

    -- -------------
    -- END PROCESSES
  end mc_sim;
