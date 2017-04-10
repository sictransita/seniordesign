library IEEE;
use ieee.numeric_std.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity garch is
  port  ( clk : in std_logic;
          lambda : in ufixed (0 downto -7);
          epsilon : in ufixed (0 downto -7);
          alpha : in ufixed (0 downto -7); -- taken out
          beta : in ufixed (0 downto -7); -- beta taken out
          sigma0 : in ufixed (0 downto -7); -- taken out

          q : out ufixed (0 downto -7);
          weps : out ufixed (0 downto -7);
          sigma : out ufixed (0 downto -7)); -- necessary?
end garch;

architecture pipelined of garch is

  -- sqrt component
  component sqrt_pipelined
  port ( clk : in std_logic;
			x : in unsigned (7 downto 0);
			osqrt : out unsigned (7 downto 0);
			odebug : out unsigned (7 downto 0));
  end component;
		
  -- iternal signals from flop inputs/ to flop outputs
  signal in_lambda : ufixed (0 downto -7) := "00000000";
  signal in_epsilon : ufixed (0 downto -7) := "00000000";
  signal in_alpha : ufixed (0 downto -7) := "00000000"; -- decimal 0.155900
  signal in_beta : ufixed (0 downto -7) := "00000000"; -- 0.840000
  signal in_sigma0 : ufixed (0 downto -7) := "00000000";
  signal in_sqrt : unsigned (7 downto 0) := "00000000";
  
  signal sqrt : unsigned (7 downto 0) := "00000000";
  signal sqrt_rem : unsigned (7 downto 0) := "00000000";
  signal out_sqrt : ufixed (0 downto -7) := "00000000";
  signal out_sqrt_rem : ufixed (0 downto -7) := "00000000";
  signal out_q : ufixed (0 downto -7) := "00000000";
  signal out_weps : ufixed (0 downto -7) := "00000000";
  signal out_sigma : ufixed (0 downto -7) := "00000000";


  -- wires in garch pipeline (refer to block diagram on google drive)
  --   #to# means pipeline stage # to #
            --> ex. w1to2 means wire from stage 1 to 2
  --   letter prefix (r, l, or c) denotes right, left, center respectively
            --> ex r3 means wire on the right in stage 3
  signal w1to2 : ufixed (0 downto -7) := "00000000";
  signal w2to3 : ufixed (0 downto -7) := "00000000";
  signal l3 : ufixed (0 downto -7) := "00000000";
  signal r3 :ufixed (0 downto -7) := "00000000";
  signal w3to4 : ufixed (0 downto -7) := "00000000";
  signal l4to5 : ufixed (0 downto -7) := "00000000";
  signal c4to5 : ufixed (0 downto -7) := "00000000";
  signal r4to5 : ufixed (0 downto -7) := "00000000";

  -- constants used in pipeline
  signal gamma : ufixed (0 downto -7) := "00000000"; -- dt/2
  signal eta : ufixed (0 downto -7) := "00000000"; -- 1 + mu*dt
  signal theta : ufixed (0 downto -7) := "00000000"; -- sqrt(dt)

  
  begin
    root: sqrt_pipelined
      port map  ( clk => clk,
                  x => in_sqrt,
                  osqrt => sqrt,
						odebug => sqrt_rem);
						
  -- process for pipeline
  process(clk)
  begin
    -- clock edge
    if (clk'EVENT and clk = '1') then
      -- input flops
      in_lambda <= lambda;
      in_epsilon <= epsilon;
      in_alpha <= alpha;
      in_beta <= beta;
      in_sigma0 <= sigma0;

      -- output flops
      q <= out_q;
      weps <= out_weps;
      sigma <= out_sigma;
		
		-- root i/o conversions
		in_sqrt <= to_unsigned(w3to4, 8);
		out_sqrt <= to_ufixed(sqrt);
		out_sqrt_rem <= to_ufixed(sqrt_rem);
		
      -- pipeline loop
      for i in 1 to 7 loop
        case i is
          -- stage 1
          when 1 => w1to2 <= in_lambda(0 downto -3) * in_lambda(0 downto -3);

          -- stage 2
          when 2 => w2to3 <= w1to2(0 downto -3) * in_beta(0 downto -3);

          -- stage 3
          when 3 => l3 <= w3to4(0 downto -3) * w2to3(0 downto -3);
                    r3 <= w3to4(0 downto -3) * in_alpha(0 downto -3);
                    w3to4 <= resize(l3 + r3 + in_sigma0, 0, -7);

          -- stage 4
          when 4 => c4to5 <= out_sqrt;
                    r4to5 <= in_epsilon(0 downto -3) * theta(0 downto -3);
                    l4to5 <= w3to4(0 downto -3) * gamma(0 downto -3);
                    out_sigma <= out_sqrt;

          -- stage 5
          when 5 => out_weps <= r4to5(0 downto -3) * c4to5(0 downto -3);
                    out_q <= resize(eta - l4to5, 0, -7);

          when others => null;
        end case;
      end loop;
    end if;
  end process;

end pipelined;
