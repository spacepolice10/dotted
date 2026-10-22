# frozen_string_literal: true

require 'test_helper'

class CompletedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'index renders lazy timeline frame for completed feed' do
    get completed_index_path

    assert_response :success
    assert_select 'main.timeline--window'
    assert_select 'turbo-frame#completed_timeline[src=?]', bullets_path(completed: true)
  end
end
