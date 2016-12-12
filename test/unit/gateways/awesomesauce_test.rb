require 'test_helper'

class AwesomesauceTest < Test::Unit::TestCase
  def setup
    @gateway = AwesomesauceGateway.new(fixtures(:awesomesauce))
    @credit_card = credit_card
    @amount = 100
    @arbitrary_transaction_id = '10'

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '44650', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal '01', response.error_code
    assert_equal 'Sandbox error', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '44680', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response

    assert_equal '01', response.error_code
    assert_equal 'Sandbox error', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(nil, @arbitrary_transaction_id)
    assert_success response

    assert_equal @arbitrary_transaction_id, response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, @arbitrary_transaction_id)
    assert_failure response

    assert_equal @arbitrary_transaction_id, response.authorization
    assert_equal '01', response.error_code
    assert_equal 'Sandbox error', response.message
  end

  def test_partial_capture
    @gateway.expects(:ssl_post).never

    assert_raise(ArgumentError) do
      @gateway.capture(@amount-1, @arbitrary_transaction_id)
    end
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(nil, @arbitrary_transaction_id)
    assert_success response

    assert_equal @arbitrary_transaction_id, response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, @arbitrary_transaction_id)
    assert_failure response

    assert_equal @arbitrary_transaction_id, response.authorization
    assert_equal '01', response.error_code
    assert_equal 'Sandbox error', response.message
  end

  def test_partial_refund
    @gateway.expects(:ssl_post).never

    assert_raise(ArgumentError) do
      @gateway.refund(@amount-1, @arbitrary_transaction_id)
    end
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@arbitrary_transaction_id)
    assert_success response

    assert_equal @arbitrary_transaction_id, response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@arbitrary_transaction_id)
    assert_failure response

    assert_equal @arbitrary_transaction_id, response.authorization
    assert_equal '01', response.error_code
    assert_equal 'Sandbox error', response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '45400', response.authorization
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response

    assert_equal '01', response.error_code
    assert_equal 'Sandbox error', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_store
    @gateway.expects(:ssl_post).never

    assert_raise(NotImplementedError) do
      @gateway.store(@credit_card, @options)
    end
  end

  private

  def pre_scrubbed
    %q(
      opening connection to sandbox.asgateway.com:80...
      opened
      <- "POST /api/auth HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.asgateway.com\r\nContent-Length: 262\r\n\r\n"
      <- "<request><merchant>sandbox-api</merchant><secret>b5639bf022eb5504020ac7bd328dee7c4a9db70e7dbd97a5393b06df587b13719ba50b373305c48e</secret><action>purch</action><amount>1.00</amount><number>4000100011112224</number><cv2>123</cv2><exp>092017</exp><name/></request>"
      -> "HTTP/1.1 200 OK \r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/html;charset=utf-8\r\n"
      -> "Content-Length: 114\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "Server: WEBrick/1.3.1 (Ruby/2.2.1/2015-02-26)\r\n"
      -> "Date: Tue, 13 Dec 2016 19:41:29 GMT\r\n"
      -> "Set-Cookie: rack.session=BAh7CEkiD3Nlc3Npb25faWQGOgZFVEkiRWQxNGFjODM4MDgzNjdmNmNiZjU2%0AMzRkZjNiMGY5MDBlZTJmNTIzNTEzOWM3NzlhMWEyNjY1MjhlYmQ4ZTczYzUG%0AOwBGSSIJY3NyZgY7AEZJIiVkYjZkNGU1ZjRiZjBlM2IzOThhNTQ3MjVlYTU2%0AMjAxMAY7AEZJIg10cmFja2luZwY7AEZ7B0kiFEhUVFBfVVNFUl9BR0VOVAY7%0AAFRJIi0xOGU0MGUxNDAxZWVmNjdlMWFlNjllZmFiMDlhZmI3MWY4N2ZmYjgx%0ABjsARkkiGUhUVFBfQUNDRVBUX0xBTkdVQUdFBjsAVEkiLWRhMzlhM2VlNWU2%0AYjRiMGQzMjU1YmZlZjk1NjAxODkwYWZkODA3MDkGOwBG%0A--17931786eecc781fb27be08b14ac9a4769088f18; path=/; HttpOnly\r\n"
      -> "Via: 1.1 vegur\r\n"
      -> "\r\n"
      reading 114 bytes...
      -> "<response><merchant>sandbox-api</merchant><success>true</success><code></code><err></err><id>44622</id></response>"
      read 114 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to sandbox.asgateway.com:80...
      opened
      <- "POST /api/auth HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.asgateway.com\r\nContent-Length: 262\r\n\r\n"
      <- "<request><merchant>sandbox-api</merchant><secret>[FILTERED]</secret><action>purch</action><amount>1.00</amount><number>[FILTERED]</number><cv2>[FILTERED]</cv2><exp>092017</exp><name/></request>"
      -> "HTTP/1.1 200 OK \r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/html;charset=utf-8\r\n"
      -> "Content-Length: 114\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "Server: WEBrick/1.3.1 (Ruby/2.2.1/2015-02-26)\r\n"
      -> "Date: Tue, 13 Dec 2016 19:41:29 GMT\r\n"
      -> "Set-Cookie: rack.session=BAh7CEkiD3Nlc3Npb25faWQGOgZFVEkiRWQxNGFjODM4MDgzNjdmNmNiZjU2%0AMzRkZjNiMGY5MDBlZTJmNTIzNTEzOWM3NzlhMWEyNjY1MjhlYmQ4ZTczYzUG%0AOwBGSSIJY3NyZgY7AEZJIiVkYjZkNGU1ZjRiZjBlM2IzOThhNTQ3MjVlYTU2%0AMjAxMAY7AEZJIg10cmFja2luZwY7AEZ7B0kiFEhUVFBfVVNFUl9BR0VOVAY7%0AAFRJIi0xOGU0MGUxNDAxZWVmNjdlMWFlNjllZmFiMDlhZmI3MWY4N2ZmYjgx%0ABjsARkkiGUhUVFBfQUNDRVBUX0xBTkdVQUdFBjsAVEkiLWRhMzlhM2VlNWU2%0AYjRiMGQzMjU1YmZlZjk1NjAxODkwYWZkODA3MDkGOwBG%0A--17931786eecc781fb27be08b14ac9a4769088f18; path=/; HttpOnly\r\n"
      -> "Via: 1.1 vegur\r\n"
      -> "\r\n"
      reading 114 bytes...
      -> "<response><merchant>sandbox-api</merchant><success>true</success><code></code><err></err><id>44622</id></response>"
      read 114 bytes
      Conn close
    )
  end

  def successful_purchase_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>true</success>
        <code></code>
        <err></err>
        <id>44650</id>
      </response>
    '
  end

  def failed_purchase_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>false</success>
        <code>01</code>
        <err>Sandbox error</err>
        <id>44660</id>
      </response>
    '
  end

  def successful_authorize_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>true</success>
        <code></code>
        <err></err>
        <id>44680</id>
      </response>
    '
  end

  def failed_authorize_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>false</success>
        <code>01</code>
        <err>Sandbox error</err>
        <id>44708</id>
      </response>
    '
  end

  def successful_capture_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>true</success>
        <code></code>
        <err></err>
        <id>10</id>
      </response>
    '
  end

  def failed_capture_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>false</success>
        <code>01</code>
        <err>Sandbox error</err>
        <id>10</id>
      </response>
    '
  end

  def successful_refund_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>true</success>
        <code></code>
        <err></err>
        <id>10</id>
      </response>
    '
  end

  def failed_refund_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>false</success>
        <code>01</code>
        <err>Sandbox error</err>
        <id>10</id>
      </response>
    '
  end

  def successful_void_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>true</success>
        <code></code>
        <err></err>
        <id>10</id>
      </response>
    '
  end

  def failed_void_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>false</success>
        <code>01</code>
        <err>Sandbox error</err>
        <id>10</id>
      </response>
    '
  end

  def successful_verify_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>true</success>
        <code></code>
        <err></err>
        <id>45400</id>
      </response>
    '
  end

  def failed_verify_response
    '
      <response>
        <merchant>sandbox-api</merchant>
        <success>false</success>
        <code>01</code>
        <err>Sandbox error</err>
        <id>10</id>
      </response>
    '
  end
end
