require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AwesomesauceGateway < Gateway
      self.test_url = 'http://sandbox.asgateway.com/api/'
      self.live_url = 'https://sandbox.asgateway.com/api/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://asgateway.com/'
      self.display_name = 'Awesomesauce'

      # Awesomesauce has unclear error code definitions.
      # It seems appropriate to not assume meanings of error codes based on
      # their documentation.

      ACTION_PATHS = {
        purchase: 'auth',
        authonly: 'auth',
        capture: 'ref',
        cancel: 'ref',
      }

      def initialize(options={})
        requires!(options, :merchant, :secret)
        super
      end

      def purchase(money, payment, options={})
        post = { :action => 'purch' }

        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit(:purchase, post)
      end

      def authorize(money, payment, options={})
        post = { :action => 'auth' }

        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit(:authonly, post)
      end

      def capture(money, authorization, options={})
        raise ArgumentError.new('Partial capture is not supported, `money` argument must be nil.') if money

        post = { :action => 'capture' }

        add_transaction_reference(post, authorization)

        commit(:capture, post)
      end

      def refund(money, authorization, options={})
        raise ArgumentError.new('Partial refund is not supported, `money` argument must be nil.') if money

        cancel(authorization, options)
      end

      def void(authorization, options={})
        cancel(authorization, options)
      end

      def verify(credit_card, options={})
        # Verifying with a zero-dollar authorization.
        authorize(0.00, credit_card, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<number>).+(</number>)), '\1[FILTERED]\2').
          gsub(%r((<cv2>).+(</cv2>)), '\1[FILTERED]\2').
          gsub(%r((<secret>).+(</secret>)), '\1[FILTERED]\2')
      end

      # Do not trust Awesomesauce enough to implement.
      def store(credit_card, options={})
        raise NotImplementedError
      end

      private

      def cancel(authorization, options={})
        post = { :action => 'cancel' }

        add_transaction_reference(post, authorization)

        commit(:cancel, post)
      end

      def add_transaction_reference(post, authorization)
        post[:ref] = authorization
      end

      def add_customer_data(post, options)
        post[:name] = options[:name]
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
      end

      def add_payment(post, payment)
        year  = format(payment.year, :four_digits)
        month = format(payment.month, :two_digits)
        expiration_date =   "#{month}#{year}"

        post[:number] = payment.number
        post[:cv2] = payment.verification_value
        post[:exp] = expiration_date
      end

      def parse(body)
        results = {}
        resp = Nokogiri::XML(body).root

        if resp.name == 'response'
          resp.children.each do |element|
            results[element.name.downcase.to_sym] = element.text
          end
        else
          results[:err] = resp.text # :err is where Awesomesauce responds with error messages.
        end

        results
      end

      def commit(action, parameters)
        response = parse(ssl_post(url(action), post_data(parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def url(action)
        base = (test? ? test_url : live_url)
        base + ACTION_PATHS[action]
      end

      def success_from(response)
        response[:success] == 'true'
      end

      def message_from(response)
        response[:err]
      end

      def authorization_from(response)
        response[:id]
      end

      def post_data(parameters = {})
        xml = Nokogiri::XML::Builder.new do |xml|
          xml.request {
            # Add authentication
            xml.merchant options[:merchant]
            xml.secret options[:secret]

            # Add parameters
            parameters.each do |k, v|
              xml.send(k, v)
            end
          }
        end.to_xml

        xml.to_s
      end

      def error_code_from(response)
        unless success_from(response)
          response[:code]
        end
      end
    end
  end
end
