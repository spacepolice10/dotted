# frozen_string_literal: true

require 'test_helper'

class AuthCodeTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test 'generate_code returns CODE_LENGTH uppercase alphanumeric string' do
    code = AuthCode.generate_code
    assert_equal AuthCode::CODE_LENGTH, code.length
    assert_match(/\A[A-Z0-9]+\z/, code)
  end

  test 'create_for returns record and plaintext code' do
    record, code = AuthCode.create_for(@user)

    assert record.persisted?
    assert_equal AuthCode::CODE_LENGTH, code.length
    assert record.code_matches?(code)
  end

  test 'create_for replaces previous codes' do
    _first_record, first_code = AuthCode.create_for(@user)
    first_record_id = @user.auth_codes.last.id

    _second_record, second_code = AuthCode.create_for(@user)

    assert_equal 1, @user.auth_codes.count
    assert_not AuthCode.exists?(id: first_record_id)
    assert @user.auth_codes.sole.code_matches?(second_code)
    assert_not @user.auth_codes.sole.code_matches?(first_code)
  end

  test 'code_matches? returns true for correct code' do
    record, code = AuthCode.create_for(@user)
    assert record.code_matches?(code)
  end

  test 'code_matches? returns false for wrong code' do
    record, _code = AuthCode.create_for(@user)
    assert_not record.code_matches?('WRONG1')
  end

  test 'code_matches? is case-insensitive' do
    record, code = AuthCode.create_for(@user)
    assert record.code_matches?(code.downcase)
  end

  test 'expired? returns false for fresh code' do
    record, _code = AuthCode.create_for(@user)
    assert_not record.expired?
  end

  test 'expired? returns true after expiry' do
    record, _code = AuthCode.create_for(@user)
    record.update!(expires_at: 1.minute.ago)
    assert record.expired?
  end

  test 'sweep deletes expired codes' do
    record, _code = AuthCode.create_for(@user)
    record.update!(expires_at: 1.minute.ago)

    assert_difference 'AuthCode.count', -1 do
      AuthCode.sweep
    end
  end

  test 'sweep keeps active codes' do
    AuthCode.create_for(@user)

    assert_no_difference 'AuthCode.count' do
      AuthCode.sweep
    end
  end

  test 'before_create sets expires_at' do
    record, _code = AuthCode.create_for(@user)
    assert_in_delta AuthCode::EXPIRY.from_now, record.expires_at, 2.seconds
  end

  test 'consume! returns user and clears codes on match' do
    _record, code = AuthCode.create_for(@user)

    consumed = AuthCode.consume!(email: @user.email_address, code: code)

    assert_equal @user, consumed
    assert_empty @user.auth_codes.reload
  end

  test 'consume! returns nil for wrong code' do
    AuthCode.create_for(@user)

    assert_nil AuthCode.consume!(email: @user.email_address, code: 'WRONG1')
    assert_equal 1, @user.auth_codes.count
  end

  test 'consume! returns nil for unknown email' do
    assert_nil AuthCode.consume!(email: 'nobody@example.com', code: 'ABC123')
  end

  test 'consume! returns nil for expired code' do
    record, code = AuthCode.create_for(@user)
    record.update!(expires_at: 1.minute.ago)

    assert_nil AuthCode.consume!(email: @user.email_address, code: code)
  end
end
