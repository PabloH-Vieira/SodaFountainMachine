LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

-- ENTITY: Mudar 'bit' para 'std_logic' é uma boa prática
ENTITY maq_refri IS
    PORT (
        Clock       : IN  std_logic; -- Mudei de bit para std_logic (Padrão VHDL)
        Reset       : IN  std_logic;
        Cinco       : IN  std_logic;
        Dez         : IN  std_logic;
        Coca        : IN  std_logic;
        Fanta       : IN  std_logic;
        DevTotal    : IN  std_logic;
        EstadoAtual : OUT std_logic_vector(13 downto 0);
        Saida       : OUT std_logic_vector(13 downto 0)
    );
END maq_refri;

ARCHITECTURE Behavior OF maq_refri IS

    -- Estados: 0, 5, 10, 15, 20, 25 centavos
    TYPE State_type IS (O, V, X, XV, XX, XXV); 
    -- Saídas: esperar, troco (5c/10c), devolução total, saída coca, saída fanta
    TYPE Exit_type  IS (esperar, troco, dev_total, coca_saida, fanta_saida);

    SIGNAL Estado      : State_type := O;
    SIGNAL ProxEstado  : State_type;
    SIGNAL Saida_Trans : Exit_type;
	 SIGNAL ProxSaida   : Exit_type;

BEGIN

    -- PROCESSO 1: REGISTRADOR DE ESTADO (Síncrono)
    -- Usa o CLOCK e o RESET
    PROCESS (Clock, Reset)
    BEGIN
        IF Reset = '1' THEN
            Estado <= O;
        -- Assumindo que você usa um clock debounced/edge-triggered
        ELSIF rising_edge(Clock) THEN 
            Estado <= ProxEstado;
				Saida_Trans <= ProxSaida;
        END IF;
    END PROCESS;

    -- PROCESSO 2: LÓGICA COMBINACIONAL (Próximo Estado e Saída)
    -- Máquina de Mealy: Saída e ProxEstado dependem do Estado Atual e das Entradas.
    PROCESS (Estado, Cinco, Dez, Coca, Fanta, DevTotal)
    BEGIN
        ProxSaida <= esperar;
        ProxEstado  <= Estado;

        -- 0. Prioridade Máxima: Devolução Total
        IF DevTotal = '1' THEN
            ProxSaida <= dev_total;
            ProxEstado <= O;
            
        -- 1. Lógica de Transição de Estados
        ELSE 
            CASE Estado IS
                
                WHEN O => -- 0 centavos
                    IF Cinco = '1' THEN
                        ProxEstado <= V;
                    ELSIF Dez = '1' THEN
                        ProxEstado <= X;
                    END IF;

                WHEN V => -- 5 centavos
                    IF Cinco = '1' THEN
                        ProxEstado <= X;
                    ELSIF Dez = '1' THEN
                        ProxEstado <= XV;
                    END IF;

                WHEN X => -- 10 centavos
                    IF Cinco = '1' THEN
                        ProxEstado <= XV;
                    ELSIF Dez = '1' THEN
                        ProxEstado <= XX;
                    END IF;

                WHEN XV => -- 15 centavos
                    IF Cinco = '1' THEN
                        ProxEstado <= XX;
                    ELSIF Dez = '1' THEN
                        ProxEstado <= XXV;
                    END IF;

                WHEN XX => -- 20 centavos (O preço é 25c)
                    -- Prioriza a entrada de 5c para atingir 25c
                    IF Cinco = '1' THEN
                        ProxEstado <= XXV;
                    -- Se inserir 10c (20 + 10 = 30):
                    ELSIF Dez = '1' THEN 
                        ProxEstado <= XXV;
                        ProxSaida <= troco; -- Saída: 5 centavos de troco (30 - 25 = 5)
                    END IF;
                    
                WHEN XXV => -- 25 centavos (Atingiu o valor)
                    -- A) Prioridade 1: Seleção de Refrigerante (Zera a máquina)
                    IF Coca = '1' THEN
                        ProxSaida <= coca_saida;
                        ProxEstado <= O;
                    ELSIF Fanta = '1' THEN
                        ProxSaida <= fanta_saida;
                        ProxEstado <= O;
                    
                    -- B) Prioridade 2: Moedas Extras (Gera Troco)
                    -- Se nenhuma bebida for selecionada, verifica se há moedas extras
                    ELSIF Cinco = '1' THEN
                        ProxEstado <= XXV;
                        ProxSaida <= troco; -- Saída: 5 centavos de troco (25 + 5 = 30, custo 25, troco 5)
                    ELSIF Dez = '1' THEN
                        ProxEstado <= XXV;
                        ProxSaida <= troco; -- Saída: 10 centavos de troco (25 + 10 = 35, custo 25, troco 10)
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

    -- PROCESSO 3: Mapeamento da SAÍDA (Combinacional)
    -- (Você deve ter um circuito decodificador para esses valores)
    Saida <= "01100011101000" WHEN Saida_Trans = troco      ELSE -- Troco (ajustado para ser genérico 5c/10c)
             "01110001000010" WHEN Saida_Trans = dev_total  ELSE -- Devolução Total
             "01110000001000" WHEN Saida_Trans = fanta_saida ELSE -- Saída Fanta
             "01100010000001" WHEN Saida_Trans = coca_saida ELSE -- Saída Coca
             "11101111110111";                                   -- Esperar/Nenhuma Saída (Default)

    -- Mapeamento do ESTADO ATUAL (Combinacional)
    -- Isso geralmente é usado para um display de 7 segmentos para mostrar o valor atual.
    EstadoAtual <= "00100100100100" WHEN Estado = XXV ELSE -- 25
                   "00100100000001" WHEN Estado = XX ELSE -- 20
                   "10011110100100" WHEN Estado = XV ELSE -- 15
                   "10011110000001" WHEN Estado = X  ELSE -- 10
                   "00000010100100" WHEN Estado = V  ELSE -- 5
                   "00000010000001";                       -- 0
                   
END Behavior;