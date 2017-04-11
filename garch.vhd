library IEEE;
use ieee.numeric_std.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity garch is
  generic ( NUM_BITS : integer := 16;
            BITS_H: integer := 15;
            BITS_L : integer := -15);

  port  ( clk : in std_logic;
          lambda : in ufixed (0 downto BITS_L);
          epsilon : in ufixed (0 downto BITS_L);
          sigma0 : in ufixed (0 downto BITS_L); -- taken out

          q : out ufixed (0 downto BITS_L);
          weps : out ufixed (0 downto BITS_L);
          sigma : out ufixed (0 downto BITS_L)); -- necessary?
end garch;

architecture pipelined of garch is

  -- sqrt component
  component sqrt_pipelined
  port ( clk : in std_logic;
			x : in unsigned (BITS_H downto 0);
			osqrt : out unsigned (BITS_H downto 0);
			odebug : out unsigned (BITS_H downto 0));
  end component;

  -- iternal signals from flop inputs/ to flop outputs
  signal in_lambda : ufixed (0 downto BITS_L) := "0000000000000000";
  signal in_epsilon : ufixed (0 downto BITS_L) := "0000000000000000";
  signal in_sigma0 : ufixed (0 downto BITS_L) := "0000000000000000";

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


  begin
  -- declare initial root array values
  root(0) <= "1000000000000000";
  sqrt_rem(0) <= "1000000000000000";

  process(clk)
  begin
    -- clock edge
    if (clk'EVENT and clk = '1') then
      -- input flops
      in_lambda <= lambda;
      in_epsilon <= epsilon;
      in_sigma0 <= sigma0;

      -- output flops
      q <= out_q;
      weps <= out_weps;
      sigma <= out_sigma;

    -- declare initial array values
 in_sqrt(0) <= to_unsigned(w3to4, NUM_BITS);
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

      -- pipeline loop
      for i in 1 to 7 loop
        case i is
          -- stage 1
          when 1 => w1to2 <= resize(in_lambda * in_lambda, 0, BITS_L);

          -- stage 2
          when 2 => w2to3 <= resize(w1to2 * beta, 0, BITS_L);

          -- stage 3
          when 3 => l3 <= resize(w3to4 * w2to3, 0 BITS_L);
                    r3 <= resize(w3to4 * alpha, 0, BITS_L);
                    w3to4 <= resize(l3 + r3 + in_sigma0, 0, BITS_L);

          -- stage 4
          when 4 => c4to5 <= to_ufixed(out_sqrt, c4to5);
                    r4to5 <= resize(in_epsilon * theta, 0, BITS_L);
                    l4to5 <= resize(w3to4 * gamma, 0, BITS_L);
                    out_sigma <= to_ufixed(out_sqrt, out_sigma);

          -- stage 5
          when 5 => out_weps <= resize(r4to5 * c4to5, 0, BITS_L);
                    out_q <= resize(eta - l4to5, 0, BITS_L);

          when others => null;
        end case;
      end loop;
    end if;
  end process;

end pipelined;
