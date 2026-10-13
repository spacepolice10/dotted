# frozen_string_literal: true

require 'test_helper'

class BulletsControllerTest < ActionDispatch::IntegrationTest
  PIXEL_PNG = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ).freeze

  setup do
    @user = users(:one)
    sign_in_as @user
    @bullet = create_bullet!(@user, body: 'Original')
  end

  test 'index does not list another user bullets' do
    private_bullet = create_bullet!(users(:two), body: 'Private bullet')

    get bullets_path

    assert_response :success
    assert_no_match private_bullet.name, response.body
  end

  test 'index returns not found for unknown collection filter' do
    get bullets_path(collection: 'missing')

    assert_response :not_found
  end

  test 'index with completed wraps feed in matching turbo frame' do
    get bullets_path(completed: true)

    assert_response :success
    assert_select 'turbo-frame#completed_timeline', minimum: 1
  end

  test 'index with completed groups done bullets by scheduled date' do
    old_done = create_bullet!(@user, body: 'Old done', pops_on: Date.current - 1)
    old_done.complete!
    fresh_done = create_bullet!(@user, body: 'Fresh done', pops_on: Date.current)
    fresh_done.complete!
    create_bullet!(@user, body: 'Not done')

    get bullets_path(completed: true)

    assert_response :success
    assert_equal 'Completed', @controller.instance_variable_get(:@filter).name
    assert_operator response.body.index('Old done'), :<, response.body.index('Fresh done')
    assert_no_match 'Not done', response.body
    assert_select '#timeline_section_yesterday .bullet', text: /Old done/
    assert_select '#timeline_section_current_date .bullet', text: /Fresh done/
    assert_select '[data-timeline-scroll-path-value=?]', bullets_path(completed: true)
  end

  test 'bullet menu gates complete and publish by selection status' do
    create_bullet!(@user, body: 'Selectable')

    get bullets_path

    assert_response :success
    assert_select '.bullet-menu--actions form[data-bullet-menu-target="complete"][hidden]', count: 1
    assert_select '.bullet-menu--actions form[data-bullet-menu-target="uncomplete"][hidden]', count: 1
    assert_select '.bullet-menu--actions form[data-bullet-menu-target="publish"][hidden]', count: 1
    assert_select '.bullet-menu--actions form[data-bullet-menu-target="unpublish"][hidden]', count: 1
    assert_match 'Complete', response.body
    assert_no_match 'Archive', response.body
    assert_select '.bullet-menu--actions button', text: 'Today', count: 0
    assert_select 'input[data-bulk-done]', minimum: 1
    assert_select 'input[data-bulk-published]', minimum: 1
    assert_select 'input[data-bulk-scheduled]', count: 0
  end

  test 'bullet menu renders pickers as native dialogs wrapping lazy frames' do
    get bullets_path

    assert_response :success
    assert_select 'dialog#postpone_dialog[closedby="any"]', minimum: 1
    assert_select 'dialog#postpone_dialog turbo-frame#postpone_picker[loading="lazy"]', minimum: 1
    assert_select 'dialog#collects_dialog[closedby="any"]', minimum: 1
    assert_select 'dialog#collects_dialog turbo-frame#collects_picker[loading="lazy"]', minimum: 1
    assert_select '[popover]', count: 0
    assert_select '[data-bullet-menu-target="popsDropdown"]', count: 0
    assert_select '[data-bullet-menu-target="collectsDropdown"]', count: 0
  end

  test 'update turbo stream replaces bullet only' do
    assert_no_difference -> { Activity.count } do
      patch bullet_path(@bullet),
            params: { bullet: { body: 'Updated' } },
            as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_no_match(/turbo-stream action="after"/, response.body)
    assert_equal 'Updated', @bullet.reload.body_as_text
  end

  test 'html create redirects to the bullet show' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { body: 'Fresh text', pops_on: Date.current.iso8601 } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_redirected_to bullet_path(bullet)
  end

  test 'create defaults to today and stays on the timeline' do
    post bullets_path, params: { bullet: { body: 'Someday' } }

    bullet = @user.bullets.order(:created_at).last
    assert_equal Date.current, bullet.pops_on
    assert_nil bullet.collection
  end

  test 'turbo stream create replaces the pending bullet' do
    client_id = SecureRandom.uuid

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { body: 'Stream text', pops_on: Date.current.iso8601, client_id: client_id } },
           as: :turbo_stream
    end

    assert_response :success
    assert_match %(turbo-stream action="replace" target="bullet_client_#{client_id}"), response.body
    assert_match 'Stream text', response.body
  end

  test 'composer create on a collection replaces the pending bullet' do
    collection = create_collection!(@user, name: 'Inbox')
    client_id = SecureRandom.uuid

    post bullets_path,
         params: { bullet: { body: '<p>Fresh today</p>', collection_id: collection.id, client_id: client_id } },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="replace" target="bullet_client_#{client_id}"), response.body
    assert_match 'Fresh today', response.body
    assert_equal collection, @user.bullets.order(:created_at).last.collection
  end

  test 'create persists rich content in body' do
    post bullets_path, params: { bullet: { body: '<h1>Long detail</h1>' } }

    bullet = @user.bullets.order(:created_at).last
    assert_match 'Long detail', bullet.body.to_plain_text
    assert_includes bullet.body.body_before_type_cast.to_s, '<h1'
  end

  test 'show renders body' do
    bullet = create_bullet!(@user, body: '<p>Expanded content</p>')

    get bullet_path(bullet)

    assert_response :success
    assert_match 'Expanded content', response.body
  end

  test 'show renders uncomplete for completed bullet' do
    bullet = create_bullet!(@user, body: 'Completed text')
    bullet.complete!

    get bullet_path(bullet)

    assert_response :success
    assert_select '#bullet_actions form[action=?][method=post]', completion_path do
      assert_select 'input[name=_method][value=delete]'
      assert_select 'button', text: /Uncomplete/
    end
  end

  test 'show renders the published link for a published bullet' do
    bullet = create_bullet!(@user, body: 'Published text')
    bullet.publish!

    get bullet_path(bullet)

    assert_response :success
    assert_select 'input.bullet--published-link[readonly]', count: 1 do |inputs|
      assert_equal published_url(bullet.public_code), inputs.first['value']
    end
  end

  test 'show omits the published link for an unpublished bullet' do
    get bullet_path(@bullet)

    assert_response :success
    assert_select 'input.bullet--published-link', count: 0
  end

  test 'show renders every bullet sharing the selected bullet day' do
    day = Date.current - 3
    focal = create_bullet!(@user, body: 'Focal', pops_on: day)
    same_day = Array.new(4) { |index| create_bullet!(@user, body: "Same day #{index}", pops_on: day) }

    get bullet_path(focal)

    assert_response :success
    assert_select "##{dom_id_of(focal)}", count: 1
    same_day.each do |bullet|
      assert_select "##{dom_id_of(bullet)}", count: 1
      assert_match bullet.body_as_text, response.body
    end
  end

  test 'show omits bullets from other days' do
    day = Date.current - 3
    focal = create_bullet!(@user, body: 'Focal', pops_on: day)
    earlier = create_bullet!(@user, body: 'Earlier day', pops_on: day - 1)
    later = create_bullet!(@user, body: 'Later day', pops_on: day + 1)

    get bullet_path(focal)

    assert_response :success
    assert_select "##{dom_id_of(earlier)}", count: 0
    assert_select "##{dom_id_of(later)}", count: 0
  end

  test 'show renders the day in timeline order' do
    day = Date.current - 3
    focal = create_bullet!(@user, body: 'Focal', pops_on: day)
    ordered = Array.new(3) do |index|
      create_bullet!(@user, body: "Line #{index}", pops_on: day, created_at: (3 - index).minutes.ago)
    end

    get bullet_path(focal)

    assert_response :success
    positions = ordered.map { |bullet| response.body.index(%(id="#{dom_id_of(bullet)}")) }
    assert positions.none?(&:nil?), 'expected every bullet of the day to render'
    assert_equal positions.sort, positions, 'expected the day in reading order'
  end

  test 'show renders no more than one day regardless of how busy it is' do
    day = Date.current - 3
    focal = create_bullet!(@user, body: 'Focal', pops_on: day)
    60.times { |index| create_bullet!(@user, body: "Bulk #{index}", pops_on: day) }

    get bullet_path(focal)

    assert_response :success
    assert_select '#timeline .bullet', 61
  end

  test 'show falls back to the bullet alone when its day has no active bullets' do
    focal = create_bullet!(@user, body: 'Completed focal', pops_on: Date.current - 3)
    focal.complete!
    same_day = create_bullet!(@user, body: 'Completed sibling', pops_on: Date.current - 3)
    same_day.complete!

    get bullet_path(focal)

    assert_response :success
    assert_select '#timeline .bullet', 1
    assert_select "##{dom_id_of(focal)}", count: 1
  end

  test 'show falls back to the bullet alone when it is not due yet' do
    focal = create_bullet!(@user, body: 'Upcoming focal', pops_on: Date.current + 2)

    get bullet_path(focal)

    assert_response :success
    assert_select '#timeline .bullet', 1
    assert_select "##{dom_id_of(focal)}", count: 1
  end

  test 'show omits another user bullets and completed bullets from the day' do
    day = Date.current - 3
    focal = create_bullet!(@user, body: 'Focal', pops_on: day)
    private_bullet = create_bullet!(users(:two), body: 'Private neighbour', pops_on: day)
    completed = create_bullet!(@user, body: 'Completed neighbour', pops_on: day)
    completed.complete!

    get bullet_path(focal)

    assert_response :success
    assert_no_match private_bullet.body_as_text, response.body
    assert_no_match completed.body_as_text, response.body
  end

  test 'show hands scrolling to the timeline controller current on the bullet' do
    get bullet_path(@bullet)

    assert_response :success
    assert_select '#timeline.timeline--scroller[data-controller=?]', 'timeline-scroll' do
      assert_select '[data-timeline-scroll-current-value=?]', 'true'
    end
  end

  test 'show renders the bullet as current for highlighting' do
    get bullet_path(@bullet)

    assert_response :success
    assert_select ".bullet--current[aria-current=true]", count: 1 do
      assert_select "##{dom_id_of(@bullet)}", count: 1
    end
  end

  test 'edit path is removed' do
    get "/bullets/#{@bullet.id}/edit"

    assert_response :not_found
  end

  test 'update changes body' do
    bullet = create_bullet!(@user, body: '<p>Old</p>')

    patch bullet_path(bullet), params: { bullet: { body: '<p>New text</p>' } }

    assert_redirected_to bullet_path(bullet)
    assert_equal 'New text', bullet.reload.body_as_text
  end

  test 'create redirects with alert when the bullet is empty' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { body: '' } }
    end

    assert_redirected_to bullets_path
    assert flash[:alert].present?
  end

  test 'new bullet path is removed' do
    get '/bullets/new'

    assert_response :not_found
  end

  test 'html create from a collection redirects to the bullet show' do
    collection = create_collection!(@user, name: 'Inbox')

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { body: 'Collection text', collection_id: collection.id } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert_equal collection, bullet.collection
    assert_redirected_to bullet_path(bullet)
  end

  test 'create stores an uploaded file as a file bullet' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path, params: { bullet: { file: file } }
    end

    bullet = @user.bullets.order(:created_at).last
    assert bullet.file.attached?
    assert_equal 'pixel.png', bullet.file.filename.to_s
    assert_empty bullet.body_as_text
    assert_equal 'pixel.png', bullet.name
  end

  test 'create rejects a bullet without content' do
    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { body: '' } }, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body['base'].present?
  end

  test 'create with client_id replaces the pending file bullet' do
    blob = create_blob!(filename: 'pixel.png', content_type: 'image/png')
    client_id = SecureRandom.uuid

    post bullets_path,
         params: { bullet: { file: blob.signed_id, client_id: client_id } },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="replace" target="bullet_client_#{client_id}"), response.body
    assert_select 'turbo-stream[action=replace] a.attachment--preview[href=?] img[alt=?][src]',
                  attachment_path(blob.signed_id), 'pixel.png'
    assert_equal client_id, @user.bullets.order(:created_at).last.client_id
  end

  test 'create with the same client_id is idempotent' do
    blob = create_blob!(filename: 'pixel.png', content_type: 'image/png')
    client_id = SecureRandom.uuid

    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { file: blob.signed_id, client_id: client_id } },
           as: :turbo_stream
    end

    assert_no_difference -> { @user.bullets.count } do
      post bullets_path,
           params: { bullet: { file: blob.signed_id, client_id: client_id } },
           as: :turbo_stream
    end

    assert_response :success
    assert_match %(turbo-stream action="replace" target="bullet_client_#{client_id}"), response.body
  end

  test 'create text with client_id replaces the pending bullet' do
    client_id = SecureRandom.uuid

    post bullets_path,
         params: { bullet: { body: 'Optimistic note', client_id: client_id } },
         as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="replace" target="bullet_client_#{client_id}"), response.body
    assert_equal 'Optimistic note', @user.bullets.order(:created_at).last.body_as_text
  end

  test 'show renders a file bullet' do
    bullet = create_file_bullet!(@user, filename: 'notes.txt')

    get bullet_path(bullet)

    assert_response :success
    assert_match 'notes.txt', response.body
  end

  test 'create json includes file details' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    post bullets_path,
         params: { bullet: { file: file } },
         headers: { 'Accept' => 'application/json' }

    assert_response :created
    assert_equal 'pixel.png', response.parsed_body['filename']
    assert_equal 'image/png', response.parsed_body['content_type']
  end

  test 'create json returns the bullet' do
    assert_difference -> { @user.bullets.count }, 1 do
      post bullets_path,
           params: { bullet: { body: '<p>API text</p>', pops_on: Date.current.iso8601 } },
           as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 'API text', body['body']
    assert_equal false, body['done']
    assert_equal bullet_url(Bullet.find(body['id'])), body['url']
    assert_equal bullet_url(Bullet.find(body['id'])), response.headers['Location']
  end

  test 'create rejects a file and a body together' do
    file = Rack::Test::UploadedFile.new(StringIO.new(PIXEL_PNG), 'image/png', original_filename: 'pixel.png')

    assert_no_difference -> { @user.bullets.count } do
      post bullets_path, params: { bullet: { body: 'Both', file: file } }
    end

    assert_redirected_to bullets_path
    assert flash[:alert].present?
  end

  test 'create json rejects a non-upload file value' do
    post bullets_path,
         params: { bullet: { body: 'Both', file: 'not-an-upload' } },
         as: :json

    assert_response :unprocessable_entity
  end

  test 'create json rejects an empty bullet' do
    post bullets_path, params: { bullet: { body: '' } }, as: :json

    assert_response :unprocessable_entity
  end

  test 'create json ignores a retired bulletable_type' do
    post bullets_path, params: { bullet: { bulletable_type: 'Memo', body: 'Nope' } }, as: :json

    assert_response :created
  end

  test 'bearer session code authenticates create json' do
    sign_out
    auth = request_login_code_json(@user.email_address)
    confirm_login_code_json(
      code: auth[:code],
      pending_authentication_code: auth[:pending_authentication_code]
    )
    session_code = response.parsed_body['session_code']
    cookies.delete('session_id')

    post bullets_path,
         params: { bullet: { body: '<p>Bearer text</p>' } },
         headers: { 'Authorization' => "Bearer #{session_code}" },
         as: :json

    assert_response :created
    assert_equal 'Bearer text', response.parsed_body['body']
  end

  test 'expired bearer session code is rejected' do
    sign_out
    session_record = @user.sessions.create!
    session_code = Rails.application.message_verifier(:session_code).generate(
      session_record.id,
      expires_in: Authentication::SESSION_CODE_EXPIRY
    )

    travel Authentication::SESSION_CODE_EXPIRY + 1.minute do
      post bullets_path,
           params: { bullet: { body: '<p>Too late</p>' } },
           headers: { 'Authorization' => "Bearer #{session_code}" },
           as: :json

      assert_response :unauthorized
    end
  end

  private

  def dom_id_of(bullet)
    ActionView::RecordIdentifier.dom_id(bullet)
  end
end
