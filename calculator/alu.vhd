library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    generic (  
        COMMAND_WIDTH : integer := 32;
        RESULT_WIDTH : integer := 8;
        ERROR_WIDTH : integer := 8;
        
        CHAR_WIDTH : integer := 8
    );
    port (
        rst_n : in std_logic;
        clk : in std_logic;
        
        -- Command input, A minimal AXI-Stream interface. 
        s_axis_cmd_tdata : in std_logic_vector(COMMAND_WIDTH-1 downto 0);
        s_axis_cmd_tvalid : in std_logic;
        s_axis_cmd_tready : out std_logic;
        
        -- Result output, A minimal AXI-Stream interface. 
        m_axis_result_tdata : out std_logic_vector(RESULT_WIDTH-1 downto 0);
        m_axis_result_tvalid : out std_logic;
        m_axis_result_tready : in std_logic;
        
        -- Error output, A minimal AXI-Stream interface.
        m_axis_error_tdata : out std_logic_vector(ERROR_WIDTH-1 downto 0);
        m_axis_error_tvalid : out std_logic;
        m_axis_error_tready : in std_logic
    );
end entity;

architecture impl of alu is
    
    type sm_state_t is (WAIT_INPUT_TRANSACTION, PREDICATE_COMMAND, WAIT_OUTPUT_TRANSACTION, WAIT_ERROR_TRANSACTION);
                        
    signal sm_state : sm_state_t;
    signal s_axis_cmd_tready_i : std_logic;
    signal m_axis_result_tvalid_i, m_axis_error_tvalid_i : std_logic;
    
    signal cmd_reg : std_logic_vector(COMMAND_WIDTH-1 downto 0) := (others => '0');
    
    signal decode_opr : std_logic_vector(CHAR_WIDTH-1 downto 0);
    signal decode_op1, decode_op2 : integer range 0 to 9;

    -- ERROR CODES:

    -- 0 = Invalid character 
    -- 1 = Invalid operator 
    -- 2 = Invalid operand
    -- 3 = Division by zero 
    -- 4 = Subtraction underflow

    constant ERROR_INVALID_OPERATOR: integer := 1; -- Custom Error Code 1 for invalid operator
    constant ERROR_DIVIDE_BY_ZERO: integer := 3; -- Custom Error Code 3 for divide by zero
    constant ERROR_UNDERFLOW: integer := 4; -- Custom Error Code 4 for underflow
    
    begin
        
        s_axis_cmd_tready <= s_axis_cmd_tready_i;
        m_axis_result_tvalid <= m_axis_result_tvalid_i;
        m_axis_error_tvalid <= m_axis_error_tvalid_i;
        
        -- Decode the command into its components: op1, operator, op2
        DECODE_AXIS_CMD_TDATA : process (cmd_reg) 
            variable ptr : integer;
            begin
            ptr := 0;
            
            decode_op1 <= to_integer(unsigned(cmd_reg(ptr+CHAR_WIDTH-1 downto ptr)));
            ptr := ptr + CHAR_WIDTH;
            
            decode_opr <= cmd_reg(ptr+CHAR_WIDTH-1 downto ptr);
            ptr := ptr + CHAR_WIDTH;
            
            decode_op2 <= to_integer(unsigned(cmd_reg(ptr+CHAR_WIDTH-1 downto ptr)));
            ptr := ptr + CHAR_WIDTH;
        end process;
        
        
        SM : process(clk) is
            begin
                if rising_edge(clk) then
                    if rst_n = '0' then
                    
                        s_axis_cmd_tready_i <= '0';
                        m_axis_result_tvalid_i <= '0';
                        m_axis_result_tdata <= (others => '-');
                        m_axis_error_tvalid_i <= '0';
                        m_axis_error_tdata <= (others => '-');
                        sm_state <= WAIT_INPUT_TRANSACTION;
                        cmd_reg <= (others => '0'); -- Reset the command register to a known state
                        
                    else
                        
                        case sm_state is
                            when WAIT_INPUT_TRANSACTION => 
                                s_axis_cmd_tready_i <= '1';
                                
                                m_axis_result_tvalid_i <= '0';
                                m_axis_result_tdata <= (others => '-');
                                
                                m_axis_error_tvalid_i <= '0';
                                m_axis_error_tdata <= (others => '-');
                                
                                -- A transaction occurs when the source asserts 'valid' and the destination asserts 'ready' on the same clock edge
                                ACCEPT_CMD : if (s_axis_cmd_tvalid = '1') and (s_axis_cmd_tready_i = '1') then 
                                    s_axis_cmd_tready_i <= '0';
                                    cmd_reg <= s_axis_cmd_tdata;
                                    sm_state <= PREDICATE_COMMAND;
                                end if; 
                                
                            when PREDICATE_COMMAND => 
                                
                                
                                if to_integer(unsigned(decode_opr)) = 43 then -- adding
                                    m_axis_result_tdata <= std_logic_vector(to_unsigned(decode_op1 + decode_op2, RESULT_WIDTH));
                                    sm_state <= WAIT_OUTPUT_TRANSACTION;
                                    
                                elsif to_integer(unsigned(decode_opr)) = 45 then -- subtracting
                                    if decode_op1 < decode_op2 then 
                                        -- Underflow error triggered:
                                        m_axis_error_tdata <= std_logic_vector(to_unsigned(ERROR_UNDERFLOW, ERROR_WIDTH));
                                        sm_state <= WAIT_ERROR_TRANSACTION;
                                    else
                                        m_axis_result_tdata <= std_logic_vector(to_unsigned(decode_op1 - decode_op2, RESULT_WIDTH));
                                        sm_state <= WAIT_OUTPUT_TRANSACTION;
                                    end if;
                                elsif to_integer(unsigned(decode_opr)) = 42 then -- multiplying
                                    m_axis_result_tdata <= std_logic_vector(to_unsigned(decode_op1 * decode_op2, RESULT_WIDTH));
                                    sm_state <= WAIT_OUTPUT_TRANSACTION;

                                elsif to_integer(unsigned(decode_opr)) = 47 then -- dividing
                                    if decode_op2 = 0 then
                                        -- Division by zero error triggered:
                                        m_axis_error_tdata <= std_logic_vector(to_unsigned(ERROR_DIVIDE_BY_ZERO, ERROR_WIDTH));
                                        sm_state <= WAIT_ERROR_TRANSACTION;
                                    else
                                        m_axis_result_tdata <= std_logic_vector(to_unsigned(decode_op1 / decode_op2, RESULT_WIDTH));
                                        sm_state <= WAIT_OUTPUT_TRANSACTION;
                                    end if;
                                else
                                    -- Invalid operator triggers an error
                                    m_axis_error_tdata <= std_logic_vector(to_unsigned(ERROR_INVALID_OPERATOR, ERROR_WIDTH));
                                    sm_state <= WAIT_ERROR_TRANSACTION;
                                end if;

                            when WAIT_OUTPUT_TRANSACTION => 
                            
                                m_axis_result_tvalid_i <= '1';
                                -- Output transaction finishes when destination asserts 'ready' and source asserts 'valid'
                                ACCEPT_OUTPUT_TRANSACTION : if (m_axis_result_tready = '1')  and (m_axis_result_tvalid_i = '1') then
                                    m_axis_result_tvalid_i <= '0';
                                    m_axis_result_tdata <= (others => '-');
                                    sm_state <= WAIT_INPUT_TRANSACTION;
                                end if;
                                
                            when WAIT_ERROR_TRANSACTION => 
                            
                                m_axis_error_tvalid_i <= '1';
                                -- Error transaction finishes when destination asserts 'ready' and source asserts 'valid'
                                ACCEPT_ERROR_TRANSACTION : if (m_axis_error_tready = '1') and (m_axis_error_tvalid_i = '1') then
                                    m_axis_error_tvalid_i <= '0';
                                    m_axis_error_tdata <= (others => '-');
                                    sm_state <= WAIT_INPUT_TRANSACTION;
                                end if;
                            
                            when others => 
                                sm_state <= WAIT_INPUT_TRANSACTION;
                                
                        end case;
                    end if;
                end if;
        end process;
       
end architecture;