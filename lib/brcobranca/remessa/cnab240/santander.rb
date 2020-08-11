# -*- encoding: utf-8 -*-
module Brcobranca
  module Remessa
    module Cnab240
      class Santander < Brcobranca::Remessa::Cnab240::Base
        # variacao da carteira
        attr_accessor :variacao

        attr_accessor :digito_agencia
        # identificacao da emissao do boleto (attr na classe base)
        #   campo nao tratado pelo sistema do Banco do Brasil
        # identificacao da distribuicao do boleto (attr na classe base)
        #   campo nao tratado pelo sistema do Banco do Brasil

        validates_presence_of :carteira, message: 'não pode estar em branco.'
        validates_presence_of :convenio, message: 'não pode estar em branco.'
        validates_length_of :conta_corrente, maximum: 9, message: 'deve ter até 9 dígitos.'
        validates_length_of :agencia, maximum: 4, message: 'deve ter 4 dígitos.'
        validates_length_of :carteira, is: 1, message: 'deve ter 1 dígito.'
        validates_length_of :convenio, maximum: 15, message: 'deve ter até 15 dígitos.'

        def initialize(campos = {})
          campos = { emissao_boleto: '0',
            distribuicao_boleto: '0',
            codigo_baixa: '00',}.merge!(campos)
          super(campos)
        end

        def cod_banco
          '033'
        end

        def nome_banco
          'Banco Santander'.ljust(30, ' ')
        end

        def versao_layout_arquivo
          '040'
        end

        def versao_layout_lote
          '030'
        end

        def codigo_convenio
          convenio.to_s.rjust(15, '0')
        end

        alias_method :convenio_lote, :codigo_convenio

        def complemento_trailer
          ''.rjust(217, ' ')
        end

        def complemento_r
          ''.rjust(61, ' ')
        end

        def complemento_p(pagamento)
          # CAMPO                   TAMANHO
          # conta corrente          12
          # digito conta            1
          # digito agencia/conta    1
          # ident. titulo no banco  20
          "#{conta_corrente.rjust(9, '0')}#{digito_conta}#{conta_corrente.rjust(9, '0')}#{digito_conta}#{''.rjust(2, ' ')}#{identificador_titulo(pagamento.nosso_numero)}"
        end

        def formata_nosso_numero(nosso_numero)
          nosso_numero.to_s.rjust(13, '0')
        end

        def identificador_titulo(nosso_numero)
          "#{formata_nosso_numero(nosso_numero)}"
        end

        # Identificacao do titulo da empresa
        #
        # Sobreescreva caso necessário
        def numero(pagamento)
          pagamento.formata_documento_ou_numero(15, ' ')
        end

        # Monta o registro segmento P do arquivo
        #
        # @param pagamento [Brcobranca::Remessa::Pagamento]
        #   objeto contendo os detalhes do boleto (valor, vencimento, sacado, etc)
        # @param nro_lote [Integer]
        #   numero do lote que o segmento esta inserido
        # @param sequencial [Integer]
        #   numero sequencial do registro no lote
        #
        # @return [String]
        #
        def monta_segmento_p(pagamento, nro_lote, sequencial)
          # campos com * na frente nao foram implementados
          #                                                             # DESCRICAO                             TAMANHO
          segmento_p = cod_banco                                        # codigo banco                          3
          segmento_p << nro_lote.to_s.rjust(4, '0')                     # lote de servico                       4
          segmento_p << '3'                                             # tipo de registro                      1
          segmento_p << sequencial.to_s.rjust(5, '0')                   # num. sequencial do registro no lote   5
          segmento_p << 'P'                                             # cod. segmento                         1
          segmento_p << ' '                                             # uso exclusivo                         1
          # Códigos de Movimento para Remessa tratados pelo Banco do Brasil:
          # 01 – Entrada de títulos,
          # 02 – Pedido de baixa,
          # 04 – Concessão de Abatimento,
          # 05 – Cancelamento de Abatimento,
          # 06 – Alteração de Vencimento,
          # 07 – Concessão de Desconto,
          # 08 – Cancelamento de Desconto,
          # 09 – Protestar,
          # 10 – Cancela/Sustação da Instrução de protesto,
          # 30 – Recusa da Alegação do Sacado,
          # 31 – Alteração de Outros Dados,
          # 40 – Alteração de Modalidade.
          segmento_p << pagamento.identificacao_ocorrencia              # cod. movimento remessa                2
          segmento_p << agencia.to_s.rjust(4, '0')                      # agencia                               5
          segmento_p << digito_agencia                                  # dv agencia                            1
          segmento_p << complemento_p(pagamento)                        # informacoes da conta                  34
          # Informar:
          # 1 – para carteira 11/12 na modalidade Simples;
          # 2 ou 3 – para carteira 11/17 modalidade Vinculada/Caucionada e carteira 31;
          # 4 – para carteira 11/17 modalidade Descontada e carteira 51;
          # e 7 – para carteira 17 modalidade Simples.
          segmento_p << carteira                                        # codigo da carteira                    1
          segmento_p << forma_cadastramento                             # forma de cadastro do titulo           1
          segmento_p << tipo_documento                                  # tipo de documento                     1
          segmento_p << ''.rjust(2, ' ')                                # uso exclusivo                         2
          segmento_p << numero(pagamento)                               # uso exclusivo                         15
          segmento_p << pagamento.data_vencimento.strftime('%d%m%Y')    # data de venc.                         8
          segmento_p << pagamento.formata_valor(15)                     # valor documento                       15
          segmento_p << ''.rjust(4, '0')                                # agencia cobradora                     5
          segmento_p << ' '                                             # dv agencia cobradora                  1
          # Para carteira 11 e 17 modalidade Simples, pode ser usado:
          # 01 – Cheque, 02 – Duplicata Mercantil,
          # 04 – Duplicata de Serviço,
          # 06 – Duplicata Rural,
          # 07 – Letra de Câmbio,
          # 12 – Nota Promissória,
          # 17 - Recibo,
          # 19 – Nota de Debito,
          # 26 – Warrant,
          # 27 – Dívida Ativa de Estado,
          # 28 – Divida Ativa de Município e
          # 29 – Dívida Ativa União.
          # Para carteira 12 (moeda variável) pode ser usado:
          # 02 – Duplicata Mercantil,
          # 04 – Duplicata de Serviço,
          # 07 – Letra de Câmbio,
          # 12 – Nota Promissória,
          # 17 – Recibo e
          # 19 – Nota de Débito.
          # Para carteira 15 (prêmio de seguro) pode ser usado:
          # 16 – Nota de Seguro e
          # 20 – Apólice de Seguro.
          # Para carteira 11/17 modalidade Vinculada e carteira 31, pode ser usado:
          # 02 – Duplicata Mercantil e
          # 04 – Duplicata de Serviço.
          # Para carteira 11/17 modalidade Descontada e carteira 51, pode ser usado:
          # 02 – Duplicata Mercantil,
          # 04 – Duplicata de Serviço, e
          # 07 – Letra de Câmbio.
          # Obs.: O Banco do Brasil encaminha para protesto os seguintes títulos:
          # Duplicata Mercantil, Rural e de Serviço, Letra de Câmbio, e
          # Certidão de Dívida Ativa da União, dos Estados e do Município.
          segmento_p << ' '
          segmento_p << pagamento.especie_titulo.to_s.rjust(2,'0')      # especie do titulo                     2
          segmento_p << aceite                                          # aceite                                1
          segmento_p << pagamento.data_emissao.strftime('%d%m%Y')       # data de emissao titulo                8
          segmento_p << pagamento.tipo_mora                             # cod. do juros                         1
          segmento_p << data_mora(pagamento)                            # data juros                            8
          segmento_p << pagamento.formata_valor_mora(15)                # valor juros                           15
          segmento_p << pagamento.cod_desconto                          # cod. do desconto                      1
          segmento_p << pagamento.formata_data_desconto('%d%m%Y')       # data desconto                         8
          segmento_p << pagamento.formata_valor_desconto(15)            # valor desconto                        15
          segmento_p << pagamento.formata_valor_iof(15)                 # valor IOF                             15
          segmento_p << pagamento.formata_valor_abatimento(15)          # valor abatimento                      15
          segmento_p << identificacao_titulo_empresa(pagamento)         # identificacao documento empresa       25

          # O Banco do Brasil trata somente os códigos
          # '1' – Protestar dias corridos,
          # '2' – Protestar dias úteis, e
          # '3' – Não protestar.
          # No caso de carteira 31 ou carteira 11/17 modalidade Vinculada,
          # se não informado nenhum código,
          # o sistema assume automaticamente Protesto em 3 dias úteis.
          segmento_p << pagamento.codigo_protesto                       # cod. para protesto                    1
          # Preencher de acordo com o código informado na posição 221.
          # Para código '1' – é possível, de 6 a 29 dias, 35o, 40o, dia corrido.
          # Para código '2' – é possível, 3o, 4o ou 5o dia útil.
          # Para código '3' preencher com Zeros.
          segmento_p << pagamento.dias_protesto.to_s.rjust(2, '0')      # dias para protesto                    2
          segmento_p << '0'                                             # cod. para baixa                       1   *'1' = Protestar Dias Corridos, '2' = Protestar Dias Úteis, '3' = Não Protestar
          segmento_p << '0'                                             # banco                      2   *
          segmento_p << '00'                                            # dias. para baixa                         2
          segmento_p << '00'                                            # cod. da moeda                         2
          segmento_p << ''.rjust(11, ' ')                               # uso exclusivo                         10
          segmento_p
        end
      end
    end
  end
end
