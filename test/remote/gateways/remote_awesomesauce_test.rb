require 'test_helper'

class RemoteAwesomesauceTest < Test::Unit::TestCase
  def setup
    @gateway = AwesomesauceGateway.new(fixtures(:awesomesauce))

    @amount = 100
    @declined_amount = 101
    @credit_card = credit_card('4000100011112224')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    # Successful responses should not have a message.
    assert_equal '', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response

    # Successful responses should not have a message.
    assert_equal '', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Sandbox error', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture

    # Successful responses should not have a message.
    assert_equal '', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Sandbox error', response.message
  end

  # Unable to confirm this test case with the Awesomesauce API.
  # Awesomesauce can only simulate failures on requests that have an `amount`.
  def test_failed_capture
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert_raise(ArgumentError) do
      assert capture = @gateway.capture(@amount-1, auth.authorization)
    end
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund

    # Successful responses should not have a message.
    assert_equal '', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert_raise(ArgumentError) do
      assert refund = @gateway.refund(@amount-1, purchase.authorization)
    end
  end

  # Unable to confirm this test case with the Awesomesauce API.
  # Awesomesauce can only simulate failures on requests that have an `amount`.
  def test_failed_refund
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void

    # Successful responses should not have a message.
    assert_equal '', void.message
  end

  # Unable to confirm this test case with the Awesomesauce API.
  # Awesomesauce can only simulate failures on requests that have an `amount`.
  def test_failed_void
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response

    # Successful responses should not have a message.
    assert_equal '', response.message
  end

  # Unable to confirm this test case with the Awesomesauce API.
  # Awesomesauce can only simulate failures on requests that have an `amount`.
  def test_failed_verify
  end

  def test_invalid_login
    gateway = AwesomesauceGateway.new(merchant: '', secret: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid security', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret], transcript)
  end

  def test_store
    assert_raise(NotImplementedError) do
      assert store = @gateway.store(@credit_card, @options)
    end
  end

end
