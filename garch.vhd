library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.MATH_REAL.ALL;

entity garch is
  port (clk : in std_logic;
        delta_t : in std_logic_vector(31 downto 0);
        lambda : in std_logic_vector(31 downto 0);
        epsilon : in std_logic_vector(31 downto 0);
        sigma_0 : in std_logic_vector(31 downto 0);
        sigma_i : out std_logic_vector(31 downto 0)
        q : out std_logic_vector(31 downto 0)
        w : out std_logic_vector(31 downto 0));
  );
end garch;

architecture behavioral of garch is
  signal alpha : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- constant
  signal beta : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- constant

  signal gamma : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- delta_t/2
  signal eta : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- (1 + mu * delta_t)
  signal theta : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- sqrt(delta_t)

  -- stage 1 temp signal (lambda squared)
  signal temp1 : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  --stage 2 temp signal (beta * lambda squared)
  signal temp2 : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  -- stage 3 multipliers and sum
  signal temp3_1 : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal temp3_2 : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal temp3_sum : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  -- stage 3 q and w operations
  signal temp_q : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal temp_epsilon : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  signal prev_temp3_sum : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  signal q : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal w : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal epsilon : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  begin
    if (rising_edge(clk)) then
      -- for loop used for pipeline stages
      for i in 0 to 4 loop
        case i is
          when 0 => temp1 <= lambda * lambda;

          when 1 => temp2 <= temp1 * beta;

          when 2 => temp3_1 <= temp2 * prev_temp3_sum;
                    temp3_2 <= alpha * prev_temp3_sum;
                    temp3_sum <= temp3_1 + temp3_2 + sigma_0;
                    temp_q <= gamma * prev_temp3_sum;
                    temp_epsilon <= epsilon * theta;

          when 3 => sigma_i <= sqrt(temp3_sum);
                    q <= eta - temp_q;

          when 4 => w <= temp_epsilon * sigma_i;

          when others => null;
        end case;
      end loop;
    end if;
  end process;
end behavioral;
