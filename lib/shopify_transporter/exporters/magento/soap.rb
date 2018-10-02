# frozen_string_literal: true

require 'json'
require 'savon'

module ShopifyTransporter
  module Exporters
    module Magento
      class Soap
        def initialize(hostname: '', username: '', api_key: '', batch_config:)
          @hostname = hostname
          @username = username
          @api_key = api_key
          @batch_config = batch_config
        end

        def call(method, params)
          soap_client.call(
            method,
            message: { session_id: soap_session_id }.merge(params)
          )
        end

        def call_in_batches(method:, params: {}, batch_index_column:)
          current_id = @batch_config['first_id']
          max_id = @batch_config['last_id']
          batch_size = @batch_config['batch_size']

          Enumerator.new do |enumerator|
            while current_id <= max_id
              end_of_range = current_id + batch_size - 1
              end_of_range = max_id if end_of_range >= max_id

              $stderr.puts "Processing batch: #{current_id}..#{end_of_range}"

              enumerator << call(
                method,
                params.merge(batching_filter(current_id, end_of_range, batch_index_column)),
              )

              current_id += batch_size
            end
          end
        end

        private

        def soap_client
          @soap_client ||= Savon.client(
            wsdl: "https://#{@hostname}/api/v2_soap?wsdl",
            open_timeout: 500,
            read_timeout: 500,
          )
        end

        def soap_session_id
          @soap_session_id ||= soap_client.call(
            :login,
            message: {
              username: @username,
              api_key: @api_key,
            }
          ).body[:login_response][:login_return]
        end

        def batching_filter(starting_id, ending_id, batch_index_column)
          {
            filters: {
              'complex_filter' => [
                item: [
                  {
                    key: batch_index_column,
                    value: {
                      key: 'in',
                      value: range_id_string(starting_id, ending_id),
                    },
                  },
                ],
              ],
            },
          }
        end

        def range_id_string(starting_id, ending_id)
          (starting_id..ending_id).to_a.join(',')
        end
      end
    end
  end
end
