library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.MATH_REAL.ALL;

entity mc_cycle is
  port (clk : in std_logic;
        delta_t : in std_logic_vector(31 downto 0);
        lambda : in std_logic_vector(31 downto 0);
        epsilon : in std_logic_vector(31 downto 0);
        sigma_0 : in std_logic_vector(31 downto 0);
        s : out std_logic_vector(31 downto 0));
  );
end mc_cycle;

architecture behavioral of mc_cycle is
  signal s_o : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal s_prev : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal s_mux : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal s_select : std_logic := '0'; -- remember this will need changing after first iteration

  signal alpha : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- constant
  signal beta : std_logic_vector(31 downto 0) := "00000000000000000000000000000000"; -- constant
  signal q : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal w : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal sigma_i : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
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
  signal prev_temp3_sum : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  -- stage 3 q and w operations
  signal temp_q : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
  signal temp_epsilon : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  -- stage 5 q plus epsilon * w
  signal temp6_sum : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";

  process(clk)
  begin
    if (rising_edge(clk)) then
      -- mc iterator mux select
      s_mux <= s_o when s_select = '0' else
            s_prev;

      -- for loop used for pipeline stages
      for i in 1 to 7 loop
        case i is
          when 1 => temp1 <= lambda * lambda;

          when 2 => temp2 <= temp1 * beta;

          when 3 => temp3_1 <= temp2 * prev_temp3_sum;
                    temp3_2 <= alpha * prev_temp3_sum;
                    temp3_sum <= temp3_1 + temp3_2 + sigma_0;
                    temp_q <= gamma * prev_temp3_sum;
                    temp_epsilon <= epsilon * theta;

          when 4 => sigma_i <= sqrt(temp3_sum);
                    q <= eta - temp_q;

          when 5 => w <= temp_epsilon * sigma_i;

          when 6 => temp6_sum <= w + q;

          when 7 => s <= s_mux * temp6_sum;

          when others => null;
        end case;
      end loop;
    end if;
  end process;
end behavioral;
