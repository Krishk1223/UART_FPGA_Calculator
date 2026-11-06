-- Used help of AI for generation of some of the backpressure test code. Arithmetic tests 
-- are all handwritten. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.ENV.ALL;

entity Test_alu is
end entity;

architecture sim of Test_alu is

    constant COMMAND_WIDTH : integer := 32;
    constant RESULT_WIDTH  : integer := 8;
    constant ERROR_WIDTH   : integer := 8;
    constant CHAR_WIDTH    : integer := 8;

    constant CLOCK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst_n : std_logic := '0';

    signal s_axis_cmd_tdata  : std_logic_vector(COMMAND_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_cmd_tvalid : std_logic := '0';
    signal s_axis_cmd_tready : std_logic;

    signal m_axis_result_tdata  : std_logic_vector(RESULT_WIDTH-1 downto 0);
    signal m_axis_result_tvalid : std_logic;
    signal m_axis_result_tready : std_logic := '0';

    signal m_axis_error_tdata  : std_logic_vector(ERROR_WIDTH-1 downto 0);
    signal m_axis_error_tvalid : std_logic;
    signal m_axis_error_tready : std_logic := '0';

begin

    -- Clock generation
    clk <= not clk after CLOCK_PERIOD / 2;

    -- Device testing
    DUT : entity work.alu
        generic map (
            COMMAND_WIDTH => COMMAND_WIDTH,
            RESULT_WIDTH  => RESULT_WIDTH,
            ERROR_WIDTH   => ERROR_WIDTH,
            CHAR_WIDTH    => CHAR_WIDTH
        )
        port map (
            rst_n => rst_n,
            clk => clk,

            s_axis_cmd_tdata => s_axis_cmd_tdata,
            s_axis_cmd_tvalid => s_axis_cmd_tvalid,
            s_axis_cmd_tready => s_axis_cmd_tready,

            m_axis_result_tdata => m_axis_result_tdata,
            m_axis_result_tvalid => m_axis_result_tvalid,
            m_axis_result_tready => m_axis_result_tready,

            m_axis_error_tdata => m_axis_error_tdata,
            m_axis_error_tvalid => m_axis_error_tvalid,
            m_axis_error_tready => m_axis_error_tready
        );


    STIMULUS : process

        -- Send a command and wait for input handshake
        procedure send_command(
            constant op1 : integer;
            constant opr : std_logic_vector(7 downto 0);
            constant op2 : integer
        ) is
        begin

            wait until falling_edge(clk);

            s_axis_cmd_tdata <= (others => '0');

            s_axis_cmd_tdata(7 downto 0) <=
                std_logic_vector(to_unsigned(op1, 8));

            s_axis_cmd_tdata(15 downto 8) <= opr;

            s_axis_cmd_tdata(23 downto 16) <=
                std_logic_vector(to_unsigned(op2, 8));

            s_axis_cmd_tvalid <= '1';

            loop
                wait until rising_edge(clk);
                exit when s_axis_cmd_tready = '1';
            end loop;

            wait until falling_edge(clk);
            s_axis_cmd_tvalid <= '0';

        end procedure;


        -- output backpressure test
        procedure check_result(
            constant expected : integer;
            constant stall_cycles : integer := 10
        ) is
        begin

            loop
                wait until rising_edge(clk);
                exit when m_axis_result_tvalid = '1';
            end loop;

            -- Check output data
            assert to_integer(unsigned(m_axis_result_tdata)) = expected
                report "Incorrect ALU result!"
                severity error;

            -- Keep result TREADY low
            for i in 1 to stall_cycles loop

                wait until rising_edge(clk);

                assert m_axis_result_tvalid = '1'
                    report "Result TVALID dropped before handshake!"
                    severity error;

                assert to_integer(unsigned(m_axis_result_tdata)) = expected
                    report "Result TDATA changed before handshake!"
                    severity error;

            end loop;

            -- output handshake
            wait until falling_edge(clk);
            m_axis_result_tready <= '1';

            wait until rising_edge(clk);

            wait until falling_edge(clk);
            m_axis_result_tready <= '0';

            report "Result test passed: " & integer'image(expected)
                severity note;

        end procedure;


        -- Check error and introduce error-channel backpressure
        procedure check_error(
            constant expected : integer;
            constant stall_cycles : integer := 10
        ) is
        begin

            loop
                wait until rising_edge(clk);
                exit when m_axis_error_tvalid = '1';
            end loop;

            assert to_integer(unsigned(m_axis_error_tdata)) = expected
                report "Incorrect ALU error code!"
                severity error;

            -- Keep error TREADY low
            for i in 1 to stall_cycles loop

                wait until rising_edge(clk);

                assert m_axis_error_tvalid = '1'
                    report "Error TVALID dropped before handshake!"
                    severity error;

                assert to_integer(unsigned(m_axis_error_tdata)) = expected
                    report "Error TDATA changed before handshake!"
                    severity error;

            end loop;

            -- Complete error handshake
            wait until falling_edge(clk);
            m_axis_error_tready <= '1';

            wait until rising_edge(clk);

            wait until falling_edge(clk);
            m_axis_error_tready <= '0';

            report "Error test passed: " & integer'image(expected)
                severity note;

        end procedure;


    begin

       
        -- reset 
        rst_n <= '0';

        wait for 3 * CLOCK_PERIOD;

        wait until falling_edge(clk);
        rst_n <= '1';

        wait for 2 * CLOCK_PERIOD;


        -- mathematical tests

        -- add
        send_command(3, x"2B", 4);
        check_result(7);

        -- subtract
        send_command(9, x"2D", 4);
        check_result(5);

        -- negative number error test
        send_command(3, x"2D", 7);
        check_error(4);

        -- multiply test
        send_command(3, x"2A", 4);
        check_result(12);

        -- divide test
        send_command(8, x"2F", 2);
        check_result(4);

        -- divide by zero error test
        send_command(8, x"2F", 0);
        check_error(3);

        -- invalid operator error test
        send_command(3, x"25", 4);
        check_error(1);


        --------------------------------------------------
        -- INPUT BACKPRESSURE + CONSECUTIVE TRANSACTIONS
        --------------------------------------------------

        report "Starting input backpressure test"
            severity note;

        -- First command: 2 + 3
        send_command(2, x"2B", 3);

        -- Immediately present a second command while ALU is busy
        wait until falling_edge(clk);

        s_axis_cmd_tdata <= (others => '0');

        s_axis_cmd_tdata(7 downto 0) <=
            std_logic_vector(to_unsigned(4, 8));

        s_axis_cmd_tdata(15 downto 8) <= x"2B";

        s_axis_cmd_tdata(23 downto 16) <=
            std_logic_vector(to_unsigned(5, 8));

        s_axis_cmd_tvalid <= '1';

        -- Verify ALU cannot accept another command while busy
        for i in 1 to 3 loop

            wait until rising_edge(clk);

            assert s_axis_cmd_tready = '0'
                report "ALU accepted a command while busy!"
                severity error;

            assert s_axis_cmd_tvalid = '1'
                report "Input tvalid dropped before handshake!"
                severity error;

            assert s_axis_cmd_tdata(7 downto 0) = x"04"
                report "Input tvalid changed before handshake!"
                severity error;

        end loop;

        -- Accept first result, with 10-cycle backpressure
        check_result(5, 10);

        -- Wait until ALU becomes ready for second command
        loop
            wait until rising_edge(clk);
            exit when s_axis_cmd_tready = '1';
        end loop;

        -- Second command has now been accepted
        wait until falling_edge(clk);
        s_axis_cmd_tvalid <= '0';

        -- Check second result
        check_result(9, 10);

        report "Input backpressure and consecutive transaction test passed"
            severity note;

        report "All tests completed"
            severity note;

        stop;

        wait;

    end process;

end architecture;
