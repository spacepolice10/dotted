# frozen_string_literal: true

require 'test_helper'

module Bullets
  class PublishesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      sign_in_as @user
      @bullet = create_bullet!(@user, body: 'Publish me')
    end

    test 'create publishes bullet and redirects to its public page' do
      post publish_path, params: { bullet_ids: @bullet.id.to_s }

      assert @bullet.reload.published?
      assert_redirected_to published_path(@bullet.public_code)
    end

    test 'create publishes bullet via turbo stream with toast' do
      post publish_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert @bullet.reload.published?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
      assert_match 'Bullet published', response.body
    end

    test 'create publishes multiple bullets' do
      other = create_bullet!(@user, body: 'Too')

      post publish_path, params: { bullet_ids: "#{@bullet.id},#{other.id}" }

      assert @bullet.reload.published?
      assert other.reload.published?
      assert_redirected_to published_path(@bullet.public_code)
    end

    test 'destroy unpublishes bullet via turbo stream' do
      @bullet.publish!

      delete publish_path,
             params: { bullet_ids: @bullet.id.to_s },
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_not @bullet.reload.published?
      assert_match %(turbo-stream action="replace" targets="#bullet_#{@bullet.id}"), response.body
      assert_match 'Bullet unpublished', response.body
    end

    test 'create returns unprocessable entity when publish! is invalid' do
      Bullet.class_eval do
        alias_method :__orig_publish!, :publish!
        def publish!
          errors.add(:base, 'cannot publish')
          raise ActiveRecord::RecordInvalid, self
        end
      end

      post publish_path,
           params: { bullet_ids: @bullet.id.to_s },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :unprocessable_entity
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
      assert_match %(turbo-stream action="update" target="toasts"), response.body
      assert_match 'cannot publish', response.body
      assert_not @bullet.reload.published?
    ensure
      Bullet.class_eval do
        alias_method :publish!, :__orig_publish!
        remove_method :__orig_publish!
      end
    end
  end
end
