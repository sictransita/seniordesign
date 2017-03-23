library IEEE;
use ieee.numeric_std.all;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity garch is
  port  ( clk : in std_logic;
          lambda : in ufixed (0 downto -31);
          epsilon : in ufixed (0 downto -31);
          alpha : in ufixed (0 downto -31);
          beta : in ufixed (0 downto -31);
          sigma0 : in ufixed (0 downto -31);

          q : out ufixed (0 downto -31);
          weps : out ufixed (0 downto -31);
          sigma : out ufixed (0 downto -31));
end garch;

architecture pipelined of garch is
  -- iternal signals from flop inputs/ to flop outputs
  signal in_lambda : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal in_epsilon : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal in_alpha : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal in_beta : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal in_sigma0 : ufixed (0 downto -31) := "00000000000000000000000000000000";

  signal out_q : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal out_weps : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal out_sigma : ufixed (0 downto -31) := "00000000000000000000000000000000";


  -- wires in garch pipeline (refer to block diagram on google drive)
  --   #to# means pipeline stage # to #
            --> ex. w1to2 means wire from stage 1 to 2
  --   letter prefix (r, l, or c) denotes right, left, center respectively
            --> ex r3 means wire on the right in stage 3
  signal w1to2 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal w2to3 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal l3 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal r3 :ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal w3to4 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal l4to5 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal c4to5 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal r4to5 : ufixed (0 downto -31) := "00000000000000000000000000000000";
  signal root_out : unsigned (31 downto 0) := "00000000000000000000000000000000";

  -- constants used in pipeline
  signal gamma : ufixed (0 downto -31) := "00000000000000000000000000000000"; -- dt/2
  signal eta : ufixed (0 downto -31) := "00000000000000000000000000000000"; -- 1 + mu*dt
  signal theta : ufixed (0 downto -31) := "00000000000000000000000000000000"; -- sqrt(dt)

  -- components (square root unit)
  component square_root
  generic (WIDTH : positive := 32);
  port (  clk	: in std_logic;
          res	: in std_logic;
          ARG	: in unsigned (WIDTH - 1 downto 0);
          Z	: out unsigned (WIDTH - 1 downto 0));
  end component;
  
  begin
  -- map ports
    root: square_root
      port map  ( clk => clk,
                  res => '0',
                  ARG => to_unsigned(w3to4, 32),
                  z => root_out);
						
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

      -- pipeline loop
      for i in 1 to 7 loop
        case i is
          -- stage 1
          when 1 => w1to2 <= in_lambda(0 downto -15) * in_lambda(0 downto -15);

          -- stage 2
          when 2 => w2to3 <= w1to2(0 downto -15) * in_beta(0 downto -15);

          -- stage 3
          when 3 => l3 <= w3to4(0 downto -15) * w2to3(0 downto -15);
                    r3 <= w3to4(0 downto -15) * in_alpha(0 downto -15);
                    w3to4 <= resize(l3 + r3 + in_sigma0, 0, -31);

          -- stage 4
          when 4 => c4to5 <= to_ufixed(root_out, 0 , -31);
                    r4to5 <= in_epsilon(0 downto -15) * theta(0 downto -15);
                    l4to5 <= w3to4(0 downto -15) * gamma(0 downto -15);
                    out_sigma <= to_ufixed(root_out, 0, -31);

          -- stage 5
          when 5 => out_weps <= r4to5(0 downto -15) * c4to5(0 downto -15);
                    out_q <= resize(eta - l4to5, 0, -31);

          when others => null;
        end case;
      end loop;
    end if;
  end process;

end pipelined;
