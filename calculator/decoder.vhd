-- Credit to E. Knight for help developing this code


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decoder is

    
    generic (
        CHAR_WIDTH : integer := 8;
        CMD_WIDTH : integer := 32;
        ERROR_WIDTH : integer := 8
    );
    port (
        clk : in std_logic;
        rst_n : in std_logic;
        
		-- Character input, A minimal AXI-Stream interface. 
        s_axis_tdata : in std_logic_vector(CHAR_WIDTH-1 downto 0); 
        s_axis_tvalid : in std_logic; 
        s_axis_tready : out std_logic; 
        
		-- ALU Command Output, A minimal AXI-Stream interface. 
        m_axis_cmd_tdata : out std_logic_vector(CMD_WIDTH-1 downto 0); 
        m_axis_cmd_tvalid : out std_logic; 
        m_axis_cmd_tready : in std_logic;
		
        -- Error Output, A minimal AXI-Stream interface. 
        m_axis_error_tdata : out std_logic_vector(ERROR_WIDTH-1 downto 0); 
        m_axis_error_tvalid : out std_logic; 
        m_axis_error_tready : in std_logic
    );
end entity;

architecture impl of decoder is
    
    
    signal s_axis_tready_i : std_logic;
    signal char_reg : std_logic_vector(CHAR_WIDTH-1 downto 0);

    
    signal m_axis_cmd_tvalid_i : std_logic;
    signal m_axis_error_tvalid_i : std_logic;
    
    type sm_state_t is (RESET, WAIT_INPUT_TRANSACTION, PREDICATE_CHAR, OUTPUT_COMMAND,
                        OUTPUT_ERROR); 
    signal sm_state : sm_state_t;
    

    type entry_t is (OPERAND_1, OPERATOR, OPERAND_2);
    
    signal operand_1_reg : std_logic_vector(CHAR_WIDTH-1 downto 0);
    signal operand_2_reg : std_logic_vector(CHAR_WIDTH-1 downto 0);
    signal operator_reg : std_logic_vector(CHAR_WIDTH-1 downto 0);
    
    constant BAD_OPERATOR_DECODE : integer := 1;
    constant BAD_OPERAND_DECODE : integer := 2;
    ---------
    signal entry : entry_t;
    
    begin
        
        s_axis_tready <= s_axis_tready_i;
        m_axis_cmd_tvalid <= m_axis_cmd_tvalid_i;
        m_axis_error_tvalid <= m_axis_error_tvalid_i;
        
        -- fix --
        --SM : process(clk) begin
        SM : process(clk) is
        
        variable digit_val : integer range 0 to 9;
        
        begin
        ---------
            if rising_edge(clk) then
                if rst_n = '0' then
                    
                    sm_state <= RESET;
                    s_axis_tready_i <= '0';
                    m_axis_cmd_tvalid_i <= '0';
                    m_axis_error_tvalid_i <= '0';
                    
                else
                    
                    case sm_state is 
                        when RESET => 
                        
                            
                            sm_state <= WAIT_INPUT_TRANSACTION;
                            s_axis_tready_i <= '0';
                            m_axis_error_tvalid_i <= '0';
                            m_axis_cmd_tvalid_i <= '0';
                            
                            -- fix --
                            --m_axis_error_tdata <= (others => '0');
                            
                            operand_1_reg <= (others => '0');
                            operand_2_reg <= (others => '0');
                            operator_reg <= (others => '0');
                            
                            entry <= OPERAND_1;
                            ---------
                            
                            
                        when WAIT_INPUT_TRANSACTION => 
                            s_axis_tready_i <= '1';

                            ACCEPT_TRANSACTION : if s_axis_tvalid = '1' and s_axis_tready_i = '1' then
                            ---------
                                s_axis_tready_i <= '0';
                                char_reg <= s_axis_tdata;
                                sm_state <= PREDICATE_CHAR;
                            end if; 
                        
                        when OUTPUT_ERROR => 
                            m_axis_error_tvalid_i <= '1';

                            OUTPUT_ERROR_TRANSACTION : if m_axis_error_tready = '1' then
                            ---------
                                m_axis_error_tvalid_i <= '0';
                                sm_state <= RESET;
                            end if;
                            
                        when OUTPUT_COMMAND => 
                            m_axis_cmd_tvalid_i <= '1';

                            OUTPUT_COMMAND_TRANSACTION : if m_axis_cmd_tvalid_i = '1' and m_axis_cmd_tready = '1' then
                            ---------
                                m_axis_cmd_tvalid_i <= '0';
                                sm_state <= RESET;
                            end if;
                        
                        
                        when PREDICATE_CHAR => 
                            
                            sm_state <= WAIT_INPUT_TRANSACTION;
                            
                            case to_integer(unsigned(char_reg)) is 
                                
                               
                                when 48 to 57 => -- 0-9. 
                                  
                                    
                                    -- fix --
                                    digit_val := to_integer(unsigned(char_reg)) - 48;
                                    ---------
                                    
                                    -- fix --
                                    --case <some parser state> is
                                        --when <parser state> => 
                                    case entry is
                                        when OPERAND_1 => 
                                            -- React accordingly
                                            operand_1_reg <= std_logic_vector(to_unsigned(digit_val, CHAR_WIDTH));
                                            
                                            entry <= OPERATOR;
                                        when OPERAND_2 =>
                                            operand_2_reg <= std_logic_vector(to_unsigned(digit_val, CHAR_WIDTH));
                                            sm_state <= OUTPUT_COMMAND;
                                    ---------
                                        when others => 
                                            -- Always remember an OTHERS. This points your SM towards known states if it ends up in an invalid state. 
                                            -- Think about how the tools will be representing these states internally, can there be other values besides the ones you give it?
                                            
                                            -- fix -- 
                                            --m_axis_error_tdata <= std_logic_vector(to_unsigned(<Your error standard!>, ERROR_WIDTH));
                                            m_axis_error_tdata <= std_logic_vector(to_unsigned(BAD_OPERAND_DECODE, ERROR_WIDTH));
                                            ---------
                                            sm_state <= OUTPUT_ERROR;
                                    end case;
                                    
                                when 43 | 45 | 42 | 47 => -- +-*/
                                    -- Similar to the incoming numbers, youll want to think about how to deal with operators. 
                                    -- You can deal with each seperately or do them as abatch. Its up to you, why might we choose either way?
                                    
                                    -- fix --  
                                    --case <some parser state> is 
                                        --when <parser state> =>
                                    case entry is
                                        when OPERATOR =>
                                            -- React accordingly
                                            operator_reg <= char_reg;
                                            entry <= OPERAND_2;
                                    ---------
                                        when others => 
                                            -- fix --
                                            --m_axis_error_tdata <= std_logic_vector(to_unsigned(<Your error standard!>, ERROR_WIDTH));
                                            m_axis_error_tdata <= std_logic_vector(to_unsigned(BAD_OPERATOR_DECODE, ERROR_WIDTH));
                                            ---------
                                            sm_state <= OUTPUT_ERROR;
                                    end case;
                                
                                    
                                when others => 
                                    m_axis_error_tdata <= std_logic_vector(to_unsigned(0, ERROR_WIDTH));
                                    sm_state <= OUTPUT_ERROR;
                            
                            end case;
                        
                        when others => 
                            sm_state <= RESET;
                            
                    end case;
                end if;
            end if;
        end process;
        
        -- Combinational logic to encode your operands & operator into a data field for the ALU instruction. 
        -- You need to come up with a standard for this.
        -- fix --
        --ENCODE_AXIS_CMD_TDATA: process(<encode variables>) 
        ENCODE_AXIS_CMD_TDATA: process(operand_1_reg, operand_2_reg, operator_reg) 
        ---------
            variable ptr : integer;
            begin
                ptr := 0;
                

				m_axis_cmd_tdata(ptr+CHAR_WIDTH-1 downto ptr) <= operand_1_reg;
				ptr := ptr + CHAR_WIDTH;
				
				m_axis_cmd_tdata(ptr+CHAR_WIDTH-1 downto ptr) <= operator_reg;
				ptr := ptr + CHAR_WIDTH;
				
				m_axis_cmd_tdata(ptr+CHAR_WIDTH-1 downto ptr) <= operand_2_reg;
				ptr := ptr + CHAR_WIDTH;

                m_axis_cmd_tdata(m_axis_cmd_tdata'high downto ptr) <= (others => '-');
                
        end process;
        
end architecture;
