library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use ieee.numeric_std.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity garch is (
  port  ( clk : in std_logic;
          lambda : in ufixed (31 downto 0);
          epsilon : in ufixed (31 downto 0);
          alpha : in ufixed (31 downto 0);
          beta : in ufixed (31 downto 0);
          sigma0 : in ufixed (31 downto 0)

          q : out ufixed (31 downto 0);
          weps : out ufixed (31 downto 0)
          sigma : out ufixed (31 downto 0));
)
end garch;

architecture pipelined of garch is
  -- iternal signals from flop inputs/ to flop outputs
  signal in_lambda : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal in_epsilon : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal in_alpha : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal in_beta : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal in_sigma0 : ufixed (31 downto 0) := "00000000000000000000000000000000";

  signal out_q : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal out_weps : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal out_sigma : ufixed (31 downto 0) := "00000000000000000000000000000000";


  -- wires in garch pipeline (refer to block diagram on google drive)
  --   #to# means pipeline stage # to #
            --> ex. 1to2 means wire from stage 1 to 2
  --   letter prefix (r, l, or c) denotes right, left, center respectively
            --> ex r3 means wire on the right in stage 3
  signal 1to2 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal 2to3 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal l3 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal r3 :ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal 3to4 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal l4to5 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal c4to5 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal r4to5 : ufixed (31 downto 0) := "00000000000000000000000000000000";
  signal root_out : ufixed (31 downto 0) := "00000000000000000000000000000000";

  -- constants used in pipeline
  signal gamma : ufixed (31 downto 0) := "00000000000000000000000000000000"; -- dt/2
  signal eta : ufixed (31 downto 0) := "00000000000000000000000000000000"; -- 1 + mu*dt
  signal theta : ufixed (31 downto 0) := "00000000000000000000000000000000"; -- sqrt(dt)

  -- components (square root unit)
  component square_root
  generic (WIDTH : positive := 32)
  port (  clk	: in std_logic;
          res	: in std_logic;
          ARG	: in unsigned (WIDTH - 1 downto 0);
          Z	: out unsigned (WIDTH - 1 downto 0));
  end component;

  -- process for pipeline
  process(clk)
  begin
    -- map ports
    root : square_root
      port map  ( clk => clk,
                  res => '0',
                  ARG => 3to4,
                  z => root_out);
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
          when 1 => 1to2 <= in_lambda * in_lambda;

          -- stage 2
          when 2 => 2to3 <= 1to2 * in_beta;

          -- stage 3
          when 3 => l3 <= 3to4 * 2to3;
                    r3 <= 3to4 * in_alpha;
                    3to4 <= l3 + r3 + in_sigma0;

          -- stage 4
          when 4 => c4to5 <= root_out;
                    r4to5 <= in_epsilon * theta;
                    l4to5 <= 3to4 * gamma;
                    out_sigma <= root_out;

          -- stage 5
          when 5 => out_weps <= r4to5 * c4to5;
                    out_q <= eta - l4to5;

          when others => null;
        end case;
      end loop;
    end if;
  end process;

end pipelined;
