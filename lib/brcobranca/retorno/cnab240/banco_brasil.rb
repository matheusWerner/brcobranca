module Brcobranca
  module Retorno
    module Cnab240
      class BancoBrasil < Brcobranca::Retorno::Cnab240::Base
        # Regex para remoção de headers e trailers além de registros diferentes de T ou U
        REGEX_DE_EXCLUSAO_DE_REGISTROS_NAO_T_OU_U = /^((?!^.{7}3.{5}[T|U].*$).)*$/

        def self.load_lines(file, options = {})
          default_options = { except: REGEX_DE_EXCLUSAO_DE_REGISTROS_NAO_T_OU_U }
          options = default_options.merge!(options)

          Line.load_lines(file, options).each_slice(2).reduce([]) do |retornos, cnab_lines|
            retornos << generate_retorno_based_on_cnab_lines(cnab_lines)
          end
        end

        def self.generate_retorno_based_on_cnab_lines(cnab_lines)
          retorno = new
          cnab_lines.each do |line|
            if line.tipo_registro == 'T'
              Line::REGISTRO_T_FIELDS.each do |attr|
                retorno.send(attr + '=', line.send(attr))
              end
            else
              Line::REGISTRO_U_FIELDS.each do |attr|
                retorno.send(attr + '=', line.send(attr))
              end
            end
          end
          retorno
        end

        # Linha de mapeamento do retorno do arquivo CNAB 240
        # O registro CNAB 240 possui 2 tipos de registros que juntos geram um registro de retorno bancário
        # O primeiro é do tipo T que retorna dados gerais sobre a transação
        # O segundo é do tipo U que retorna os valores da transação
        class Line < Base
          extend ParseLine::FixedWidth # Extendendo parseline

          REGISTRO_T_FIELDS = %w(codigo_registro codigo_ocorrencia agencia_com_dv cedente_com_dv nosso_numero carteira data_vencimento valor_titulo banco_recebedor agencia_recebedora_com_dv sequencial valor_tarifa motivo_ocorrencia)
          REGISTRO_U_FIELDS = %w(desconto_concedito data_ocorrencia valor_abatimento iof_desconto juros_mora valor_recebido outras_despesas outros_recebimento data_credito)

          attr_accessor :tipo_registro

          fixed_width_layout do |parse|
            parse.field :codigo_registro, 8..8
            parse.field :sequencial, 9..13
            parse.field :tipo_registro, 14..14
            parse.field :codigo_ocorrencia, 16..17
            parse.field :agencia_com_dv, 18..23
            parse.field :cedente_com_dv, 24..36
            parse.field :nosso_numero, 38..57
            parse.field :carteira, 58..58
            parse.field :data_vencimento, 74..81
            parse.field :valor_titulo, 82..96
            parse.field :banco_recebedor, 97..99
            parse.field :agencia_recebedora_com_dv, 100..105
            parse.field :data_ocorrencia, 158..165
            parse.field :data_credito, 146..153
            parse.field :outras_despesas, 108..122
            parse.field :iof_desconto, 63..77
            parse.field :valor_abatimento, 48..62
            parse.field :desconto_concedito, 33..47
            parse.field :valor_recebido, 78..92
            parse.field :juros_mora, 18..32
            parse.field :outros_recebimento, 123..137
            parse.field :valor_tarifa, 199..213
            parse.field :motivo_ocorrencia, 214..223, ->(motivos) do
              motivos.scan(/.{2}/).reject(&:blank?).reject{|motivo| motivo == '00'}
            end

            # Dados que não consegui extrair dos registros T e U
            # parse.field :convenio,31..37
            # parse.field :tipo_cobranca,80..80
            # parse.field :tipo_cobranca_anterior,81..81
            # parse.field :natureza_recebimento,86..87
            # parse.field :carteira_variacao,91..93
            # parse.field :desconto,95..99
            # parse.field :iof,100..104
            # parse.field :comando,108..109
            # parse.field :data_liquidacao,110..115
            # parse.field :especie_documento,173..174
            # parse.field :valor_tarifa,181..187
            # parse.field :juros_desconto,201..213
            # parse.field :abatimento_nao_aproveitado,292..304
            # parse.field :valor_lancamento,305..317
            # parse.field :indicativo_lancamento,318..318
            # parse.field :indicador_valor,319..319
            # parse.field :valor_ajuste,320..331
          end
        end
      end
    end
  end
end
