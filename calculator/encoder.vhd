-- Credit to E. Knight for help developing this code


library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;

entity encoder_alu_result is



    generic (
        RESULT_WIDTH : integer := 32;
        CHAR_WIDTH : integer := 8
    );
    port (
        clk : in std_logic;
        rst_n : in std_logic;
        
        -- ALU Result input, A minimal AXI-Stream interface. 
        s_axis_result_tdata : in std_logic_vector(RESULT_WIDTH-1 downto 0); 
        s_axis_result_tvalid : in std_logic; 
        s_axis_result_tready : out std_logic; 
        
        -- Character result output, An augmented AXI-stream interface.
        m_axis_tdata : out std_logic_vector(CHAR_WIDTH-1 downto 0); 
        m_axis_tvalid : out std_logic; 
        m_axis_tready : in std_logic;
        m_axis_tlast : out std_logic
    );
end entity;

architecture impl of encoder_alu_result is
        
        
    type sm_state_t is (WAIT_INPUT, PREDICATE_VALUE, WAIT_OUTPUT);
    signal sm_state : sm_state_t;
    
    signal s_axis_result_tready_i : std_logic;
    signal m_axis_tvalid_i : std_logic;
    
 
    
    -- fix --
    --signal val : integer range <your range here>;
    signal val : integer range -1 to 99;
    ---------
    
    begin
        
        s_axis_result_tready <= s_axis_result_tready_i;    
        m_axis_tvalid <= m_axis_tvalid_i;
        
        SM : process(clk) is
            begin
            if rising_edge(clk) then
                if rst_n = '0' then
                
                    sm_state <= WAIT_INPUT;
                    s_axis_result_tready_i <= '0';
                    m_axis_tvalid_i <= '0';
                    m_axis_tlast <= '0';
                    m_axis_tdata <= (others => '-');
                    
                else
                    
                    case sm_state is 
                        when WAIT_INPUT => 
                        
                            s_axis_result_tready_i <= '1';
                            -- fix --
                            --ACCEPT_TRANSACTION : if <conditions!> then
                            ACCEPT_TRANSACTION : if s_axis_result_tvalid = '1' and s_axis_result_tready_i = '1' then
                            ---------
                                s_axis_result_tready_i <= '0';
                                sm_state <= PREDICATE_VALUE;
                                -- You'll want to save the tdata on the input transaction to a register (hint, we provide that in the declarative section!)
                                -- fix --
                                val <= to_integer(unsigned(s_axis_result_tdata));                              
                                ---------
                            end if;
                        
                        when PREDICATE_VALUE => 
                        
                            sm_state <= WAIT_OUTPUT;
                            m_axis_tlast <= '0';
                            
                            if val = -1 then
                                 sm_state <= WAIT_INPUT;
                                 
                            elsif val >= 10 then
                                
                                
                                -- fix --
                                 --m_axis_tdata <= std_logic_vector(<THE FIRST CHAR>);
                                 m_axis_tdata <= std_logic_vector(to_unsigned(48 + val/10, CHAR_WIDTH));
                                 ---------
                                 val <= val mod 10;
                            else 
                                -- fix --
                                --m_axis_tdata <= std_logic_vector(<THE SECOND CHAR>);
                                m_axis_tdata <= std_logic_vector(to_unsigned(48 + val, CHAR_WIDTH));
                                ---------
                                m_axis_tlast <= '1'; -- Think about the significance of driving tlast here... What does that suggest about the interface? 
                                val <= -1;
                            end if;
                        
                        when WAIT_OUTPUT=> 
                        
                            m_axis_tvalid_i <= '1';
                            -- fix --
                            --GENERATE_TRANSACTION : if <conditions!> then
                            GENERATE_TRANSACTION : if m_axis_tvalid_i = '1' and m_axis_tready = '1' then
                            ---------
                                m_axis_tvalid_i <= '0';
                                m_axis_tdata <= (others => '-');
                                m_axis_tlast <= '0';
                                sm_state <= PREDICATE_VALUE;
                            end if;

                    end case;
                    
                end if;
            end if;
        end process;
end architecture;
